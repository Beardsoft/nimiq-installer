#!/usr/bin/env python3

import os
import requests
import json
import time
import argparse
import logging
from prometheus_client import start_http_server, Gauge


NIMIQ_NODE_URL = 'http://node:8648'
FACUET_URL = 'https://faucet.pos.nimiq-testnet.com/tapit'

# Prometheus Metrics
ACTIVATED_AMOUNT = Gauge('nimiq_activated_amount', 'Amount activated', ['address'])

logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s — %(message)s',
                    datefmt='%Y-%m-%d_%H:%M:%S',
                    handlers=[logging.StreamHandler()])

def nimiq_request(method, params=None, retries=3, delay=5):
    while retries > 0:
        try:
            response = requests.post(NIMIQ_NODE_URL, json={
                "jsonrpc": "2.0",
                "id": 1,
                "method": method,
                "params": params or [],
            })
            response.raise_for_status()  # Raises an HTTPError if the HTTP request returned an unsuccessful status code

            result = response.json().get('result', {})
            if result is None:
                raise ValueError("No result in response")
            return result

        except requests.exceptions.RequestException as err:
            retries -= 1
            logging.error(f"Error: {err}. Retrying in {delay} seconds. Retries left: {retries}")
            time.sleep(delay)

    logging.error("Request failed after multiple retries.")
    return None

def get_private_key(file_path):
    with open(file_path, 'r') as f:
        lines = f.readlines()
        for line in lines:
            if 'Private Key:' in line:
                return line.split('Private Key:')[1].strip()
    return None

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

def activate_validator(private_key_location):
    ADDRESS = get_address()
    logging.info(f"Address: {ADDRESS}")

    res = nimiq_request("getSigningKey")
    if res is None:
        return
    SIGKEY = res['data']
    logging.info(f"Signing Key: {SIGKEY}")

    res = nimiq_request("getVotingKey")
    if res is None:
        return
    VOTEKEY = res['data']
    logging.info(f"Voting Key: {VOTEKEY}")

    ADDRESS_PRIVATE = get_private_key(private_key_location)

    logging.info("Funding Nimiq address.")
    if needs_funds(ADDRESS):
        requests.post(FACUET_URL, data={'address': ADDRESS})
        logging.info("Importing private key.")
        nimiq_request("importRawKey", [ADDRESS_PRIVATE])

        logging.info("Unlock Account.")
        nimiq_request("unlockAccount", [ADDRESS])
    else:
        logging.info("Address already funded.")

    logging.info("Activate Validator")
    nimiq_request("sendNewValidatorTransaction", [ADDRESS, ADDRESS, SIGKEY, VOTEKEY, ADDRESS, "", "0"])
    
    ACTIVATED_AMOUNT.labels(address=ADDRESS).set(1)  # Assuming amount activated is 1, adjust as needed
    return ADDRESS

def is_validator_active(address):
    res = nimiq_request("getActiveValidators")
    if res is None:
        return False
    active_validators = res.get('data', [])
    logging.info(json.dumps({"active_validators": active_validators}))
    return address in active_validators

def check_and_activate_validator(private_key_location, address):
    if not is_validator_active(address):
        activate_validator(private_key_location)
    else:
        logging.info("Validator already active.")

def check_block_height():
    logging.info("Waiting for consensus to be established, this may take a while...")
    logging.info("Don't close this window!")
    while True:
        res = nimiq_request("isConsensusEstablished")
        if res is not None and res.get('data') == True:
            logging.info("Consensus established.")
            break
        else:
            time.sleep(5)

if __name__ == '__main__':
    start_http_server(8000)  # Start Prometheus client
    logging.info(40 * '-')
    logging.info('Nimiq validator activation script')
    logging.info(40 * '-')
    parser = argparse.ArgumentParser(description='Activate Validator')
    parser.add_argument('--private-key', type=str, default="/keys/address.txt", help='Path to the private key file')
    args = parser.parse_args()
    # Run indefinitely
    while True:
        check_block_height()
        address = get_address()
        check_and_activate_validator(args.private_key, address)
        time.sleep(180)  # Wait for a minute before checking again
