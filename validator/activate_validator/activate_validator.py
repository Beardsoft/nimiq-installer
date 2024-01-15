#!/usr/bin/env python3

import os
import requests
import json
import time
import logging
from prometheus_client import start_http_server, Gauge

NIMIQ_NODE_URL  = os.getenv('NIMIQ_NODE_URL', 'http://node:8648')
NIMIQ_NETWORK   = os.getenv('NIMIQ_NETWORK', 'testnet')
FACUET_URL      = os.getenv('FACUET_URL','https://faucet.pos.nimiq-testnet.com/tapit')
PROMETHEUS_PORT = os.getenv('PROMETHEUS_PORT', 8000)

# Prometheus Metrics
ACTIVATED_AMOUNT = Gauge('nimiq_activated_amount', 'Amount activated', ['address'])
ACTIVATE_EPOCH = Gauge('nimiq_activate_epoch', 'Epoch tried to activate validator')
EPOCH_NUMBER = Gauge('nimiq_epoch_number', 'Epoch number')
CURRENT_BALANCE = Gauge('nimiq_current_balance', 'Current balance')
TOTAL_STAKE = Gauge('nimiq_validator_total_stake', 'Total amount of stake')
CURRENT_STAKERS = Gauge('nimiq_validator_current_stakers', 'Current amount of stakers')

logging.basicConfig(level=logging.DEBUG,
                    format='%(asctime)s — %(message)s',
                    datefmt='%Y-%m-%d_%H:%M:%S',
                    handlers=[logging.StreamHandler()])

def store_activation_epoch(epoch):
    with open("activation_epoch.txt", "w") as file:
        file.write(str(epoch))
    ACTIVATE_EPOCH.set(epoch)

def read_activation_epoch():
    if os.path.exists("activation_epoch.txt"):
        with open("activation_epoch.txt", "r") as file:
            return int(file.read().strip())
    return None

def nimiq_request(method, params=None, retries=3, delay=5):
    while retries > 0:
        try:
            logging.debug(method)
            logging.debug(params)
            response = requests.post(NIMIQ_NODE_URL, json={
                "jsonrpc": "2.0",
                "id": 1,
                "method": method,
                "params": params or [],
            })
            response.raise_for_status()  # Raises an HTTPError if the HTTP request returned an unsuccessful status code
            logging.debug(response.json())
            result = response.json().get('result', {})
            time.sleep(0.5) # Wait for 0.5 second to not overload the node.
            if result is None:
                raise ValueError("No result in response")
            return result

        except requests.exceptions.RequestException as err:
            retries -= 1
            logging.error(f"Error: {err}. Retrying in {delay} seconds. Retries left: {retries}")
            time.sleep(delay)
    logging.error("Request failed after multiple retries.")
    return None

def get_public_key(file_path):
    with open(file_path, 'r') as f:
        lines = f.readlines()
        for line in lines:
            if 'Private Key:' in line:
                return line.split('Private Key:')[1].strip()
    return None

def get_private_key(file_path):
    with open(file_path, 'r') as f:
        lines = f.readlines()
        for line in lines:
            if 'Private Key:' in line:
                return line.split('Private Key:')[1].strip()
    return None

def get_wallet_address(file_path):
    with open(file_path, 'r') as f:
        lines = f.readlines()
        for line in lines:
            if 'Address:' in line:
                return line.split('Address:')[1].strip()
    return None

def get_vote_key(file_path):
    with open(file_path, 'r') as file:
        lines = file.readlines()
    for i in range(len(lines)):
        if "Secret Key:" in lines[i]:
            secret_key = lines[i+2].strip()  # The secret key is two lines down
    return secret_key

def needs_funds(address):
    res = nimiq_request("getAccountByAddress", [address])
    if res is None:
        return False
    data = res.get('data', {})
    if data is None or data.get('balance', 0) == 0:
        return True
    else:
        return False

def get_address():
    res = nimiq_request("getAddress")
    if res is None:
        return None
    return res['data']

def get_tx(tx_hash):
    res = nimiq_request("getTransactionByHash", [tx_hash])
    if res is None:
        return None
    if 'error' in res:
        logging.error(f"Error getting transaction: {res['error']['message']}")
        return None
    logging.info(f"Transaction: {res}")

def push_raw_tx(tx_hash):
    res = nimiq_request("pushTransaction", [tx_hash])
    logging.info(f"Transaction: {res}")
    if res is None:
        return None
    if 'error' in res:
        logging.error(f"Error pushing transaction: {res['error']['message']}")
        return None
    logging.info(f"Transaction: {res}")

def get_epoch_number():
    res = nimiq_request("getEpochNumber")
    if res is None:
        return None
    EPOCH_NUMBER.set(res['data'])

def set_balance_prometheus(address):
    balance = get_balance(address)
    if balance is not None:
        balance = balance / 1e5  # Convert to NIM
        CURRENT_BALANCE.set(balance)
    else:
        logging.error("Error getting balance.")
    return balance

def get_stake_by_address(address):
    res = nimiq_request("getValidatorByAddress", [address])
    if res is not None and 'data' in res:
        balance = res['data'].get('balance', 0) / 1e5  # Convert to NIM
        num_stakers = res['data'].get('numStakers', 0)
        CURRENT_BALANCE.set(balance)
        CURRENT_STAKERS.set(num_stakers)
    else:
        logging.error("Error getting stake information.")
    return balance, num_stakers

def get_balance(address):
    res = nimiq_request("getAccountByAddress", [address])
    if res is None:
        return None
    if 'error' in res:
        logging.error(f"Error getting balance: {res['error']['message']}")
        return None
    return res['data']['balance']

def wait_for_enough_stake(ADDRESS):
    while True:
        balance = get_balance(ADDRESS)
        if balance is not None:
            balance = balance / 1e5  # Convert to NIM
            CURRENT_BALANCE.set(balance)
            if balance >= 100000:  # Check if balance is at least 100k NIM
                logging.info(f"Balance reached: {balance} NIM.")
                break
            else:
                logging.info(f"Current balance: {balance} NIM. Waiting for balance to reach 100k NIM.")
        else:
            logging.error("Error getting balance.")
        time.sleep(60)  # Wait for 1 minute

def monitor_active_validator(address):
    while True:
        if is_validator_active(address):
            logging.info("Validator still active.")
            set_balance_prometheus(address)
            get_epoch_number()
            
            
        else:
            logging.info("Validator not active anymore.")
            break
        time.sleep(60)  # Wait for 1 minute

def activate_validator():
    ADDRESS = get_address()
    logging.info(f"Address: {ADDRESS}")
    
    FEE_PUB_KEY = get_wallet_address('/keys/fee_key.txt')

    SIGKEY = get_public_key('/keys/signing_key.txt')

    VOTEKEY = get_vote_key('/keys/vote_key.txt')

    ADDRESS_PRIVATE = get_private_key('/keys/address.txt')

    logging.info("Funding Nimiq address.")
    if needs_funds(ADDRESS):
        requests.post(FACUET_URL, data={'address': ADDRESS})
    else:
        logging.info("Address already funded.")

    current_epoch = nimiq_request("getEpochNumber")['data']
    store_activation_epoch(current_epoch)

    logging.info("Importing private key.")
    nimiq_request("importRawKey", [ADDRESS_PRIVATE, ''])

    logging.info("Unlock Account.")
    nimiq_request("unlockAccount", [ADDRESS, '', 0])

    logging.info("Wait for enough stake.")
    wait_for_enough_stake(ADDRESS)

    logging.info("Activate Validator")
    result = nimiq_request("createNewValidatorTransaction", [ADDRESS, ADDRESS, SIGKEY, VOTEKEY, ADDRESS, "", 500, "+0"])
    
    logging.info("Pushing transaction")
    push_raw_tx(result.get('data'))

    ACTIVATED_AMOUNT.labels(address=ADDRESS).inc()
    return ADDRESS

def is_validator_active(address):
    res = nimiq_request("getActiveValidators")
    if res is None:
        return False
    active_validators = res.get('data', [])
    logging.info(json.dumps({"active_validators": active_validators}))
    return address in active_validators

def check_and_activate_validator(address):
    current_epoch = nimiq_request("getEpochNumber")['data']
    activation_epoch = read_activation_epoch()
    if activation_epoch is None or current_epoch > activation_epoch:
        if not is_validator_active(address):
            logging.info("Activating validator.")
            activate_validator()
        else:
            logging.info("Validator already active.")
            monitor_active_validator(address)
    else:
        next_epoch = activation_epoch + 1
        logging.info(f"Next epoch to activate validator: {next_epoch}")
        logging.info("Waiting for next epoch to activate validator.")

def check_block_height():
    logging.info("Waiting for consensus to be established, this may take a while...")
    consensus_count = 0
    while consensus_count < 3:
        res = nimiq_request("isConsensusEstablished")
        if res is not None and res.get('data') == True:
            consensus_count += 1
            logging.info(f"Consensus established {consensus_count} time(s).")
        else:
            consensus_count = 0
            logging.info("Consensus not established yet.")
        time.sleep(5)
    logging.info("Consensus confirmed 3 times.")

if __name__ == '__main__':
    logging.info("Starting  validator activation script...")
    logging.info(f"Version: 0.2.0 ")
    start_http_server(int(PROMETHEUS_PORT))  # Start Prometheus client
    # Run indefinitely
    while True:
        check_block_height()
        get_epoch_number()
        address = get_address()
        check_and_activate_validator(address)
        time.sleep(600)  # Wait for 10 minutes to check again.
