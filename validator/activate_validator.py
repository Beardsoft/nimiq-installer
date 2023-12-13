#!/usr/bin/env python3 

import os
import requests
import json
import time
import argparse
import logging

NIMIQ_NODE_URL = 'http://127.0.0.1:8648'
EXTERNAL_API_URL = 'https://rpc.nimiqcloud.com/'
FACUET_URL = 'https://faucet.pos.nimiq-testnet.com/tapit'

logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s — %(message)s',
                    datefmt='%Y-%m-%d_%H:%M:%S',
                    handlers=[logging.StreamHandler()])

def nimiq_request(method, params=None):
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

    except requests.exceptions.HTTPError as errh:
        logging.error("Http Error:", errh)
    except requests.exceptions.ConnectionError as errc:
        logging.error("Error Connecting:", errc)
    except requests.exceptions.Timeout as errt:
        logging.error("Timeout Error:", errt)
    except requests.exceptions.RequestException as err:
        logging.error("Error: Something went wrong with the request", err)
    except ValueError as err:
        logging.error("Error: Invalid response format", err)

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

def activate_validator(private_key_location):
    # Get address data
    res = nimiq_request("getAddress")
    ADDRESS = res['data']
    logging.info("Address: %s", ADDRESS)

    res = nimiq_request("getSigningKey")
    SIGKEY = res['data']
    logging.info("Signing Key: %s", SIGKEY)

    res = nimiq_request("getVotingKey")
    VOTEKEY = res['data']
    logging.info("Voting Key: %s", VOTEKEY)

    logging.info("Funding Nimiq address.")
    if needs_funds(ADDRESS):
        requests.post(FACUET_URL, data={'address': ADDRESS})
    else:
        logging.info("Address already funded.")

    ADDRESS_PRIVATE = get_private_key(private_key_location)
    logging.info("Importing private key.")
    nimiq_request("importRawKey", [ADDRESS_PRIVATE])

    logging.info("Unlock Account.")
    nimiq_request("unlockAccount", [ADDRESS])

    logging.info("Activate Validator")
    nimiq_request("sendNewValidatorTransaction", [ADDRESS, ADDRESS, SIGKEY, VOTEKEY, ADDRESS, "", "0"])

def check_block_height():
    logging.info("Waiting for consensus to be established, this may take a while...")
    logging.info("Don't close this window!")
    while True:
        res = nimiq_request("isConsensusEstablished")
        if res['data'] == True:
            logging.info("Consensus established.")
            break
        else:
            time.sleep(5)

if __name__ == '__main__':
    logging.info(40 * '-')
    logging.info('Nimiq validator activation script')
    logging.info(40 * '-')
    parser = argparse.ArgumentParser(description='Activate Validator')
    parser.add_argument('--private-key', type=str, default="/opt/nimiq/secrets/address.txt" , help='Path to the private key file')
    args = parser.parse_args()
    check_block_height()
    activate_validator(args.private_key)
