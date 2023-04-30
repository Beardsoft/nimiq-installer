#!/usr/bin/env python3 

import os
import requests
import json
import time
import argparse
import logging
import subprocess
import shutil

NIMIQ_NODE_URL = 'http://127.0.0.1:8648'
FACUET_URL = 'https://faucet.pos.nimiq-testnet.com/tapit'
DOCKER_IMAGE = 'maestroi/nimiq-albatross:stable'
BASE_FOLDER = '/opt/nimiq'

logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s — %(message)s',
                    datefmt='%Y-%m-%d_%H:%M:%S',
                    handlers=[logging.StreamHandler()])

def start_docker_container():
    subprocess.run(["docker-compose", "down"], cwd="/opt/nimiq/configuration", stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["docker-compose", "up", "-d"], cwd="/opt/nimiq/configuration", stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    logging.info("Started Docker containers")

def generate_nimiq_address(output_file):
    # Check if the output file already exists
    if os.path.isfile(output_file):
        logging.info(f"The file {output_file} already exists.")
    else:
        # Create the Docker container and run the command
        cmd = f"docker run --rm {DOCKER_IMAGE} nimiq-address"
        with open(output_file, 'w') as f:
            subprocess.run(cmd.split(), stdout=f, stderr=subprocess.DEVNULL)

def generate_nimiq_bls(output_file):
    # Check if the output file already exists
    if os.path.isfile(output_file):
        logging.info(f"The file {output_file} already exists.")
    else:
        # Create the Docker container and run the command
        logging.info("Generating a new Nimiq address.")
        cmd = f"docker run --rm --name nimiq-address {DOCKER_IMAGE} nimiq-bls"
        with open(output_file, 'w') as f:
            subprocess.run(cmd.split(), stdout=f, stderr=subprocess.DEVNULL)

def install_validator(version, network):
    secrets_folder = f'{BASE_FOLDER}/secrets'
    config_folder = f'{BASE_FOLDER}/configuration'
    files = {
        'address': f'{secrets_folder}/address.txt',
        'fee_key': f'{secrets_folder}/fee_key.txt',
        'signing_key': f'{secrets_folder}/signing_key.txt',
        'vote_key': f'{secrets_folder}/vote_key.txt'
    }
    
    for key, path in files.items():
        logging.info(f"Generating {key} secrets.")
        if key == 'vote_key':
            generate_nimiq_bls(path)
        else:
            generate_nimiq_address(path)

    # Download Docker Compose file
    logging.info(f"Downloading Docker Compose file validator node.")
    r = requests.get(f"https://raw.githubusercontent.com/maestroi/nimiq-installer/{version}/validator/Docker-compose.yaml", stream=True)
    with open(f"{config_folder}/docker-compose.yaml", 'wb') as f:
        r.raw.decode_content = True
        shutil.copyfileobj(r.raw, f)

    # Download config files
    if network == "testnet":
        logging.info(f"Downloading config file: testnet-config.toml.")
        r = requests.get(f"https://raw.githubusercontent.com/maestroi/nimiq-installer/{version}/validator/testnet-config.toml", stream=True)
        with open(f"{config_folder}/client.toml", 'wb') as f:
            r.raw.decode_content = True
            shutil.copyfileobj(r.raw, f)
    elif network == "mainnet":
        logging.info(f"Downloading config file: mainnet-config.toml.")
        r = requests.get(f"https://raw.githubusercontent.com/maestroi/nimiq-installer/{version}/validator/mainnet-config.toml", stream=True)
        with open(f"{config_folder}/client.toml", 'wb') as f:
            r.raw.decode_content = True
            shutil.copyfileobj(r.raw, f)
    else:
        logging.info(f"Invalid network parameter. Please use testnet or mainnet.")
        exit(1)

    #Set paths
    configuration_file=f"{config_folder}/client.toml"
    # Read values from /opt/nimiq/secrets/nimiq-address.txt
    values = {}
    for key, path in files.items():
        with open(path, 'r') as f:
            contents = f.read()
            if 'Address:' in contents:
                values[key] = contents.split('Address:')[1].strip()
            elif 'Private Key:' in contents:
                values[key] = contents.split('Private Key:')[1].split()[0]

    # Update client.toml
    with open(configuration_file, 'r') as f:
        contents = f.read()
    contents = contents.replace('CHANGE_VALIDATOR_ADDRESS', values['address'])
    contents = contents.replace('CHANGE_FEE_KEY', values['fee_key'])
    contents = contents.replace('CHNAGE_SIGN_KEY', values['signing_key'])
    contents = contents.replace('CHANGE_VOTE_KEY', values['vote_key'])
    
    start_docker_container()

def nimiq_request(method, params=None):
    response = requests.post(NIMIQ_NODE_URL, json={
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,
        "params": params or [],
    })
    if response.status_code != 200:
        logging.error(f"Error: {response.status_code}")
        return None
    result = response.json().get('result', {})
    if result is None:
        logging.error(f"Error: {response.text}")
        return None
    return result

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

def activate_validator():
    # Get address data
    private_key_location = f'{BASE_FOLDER}/secrets/address.txt'
    
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
    logging.info("Waiting for consensus to be established.")
    while True:
        res = nimiq_request("isConsensusEstablished")
        if res['data'] == True:
            logging.info("Consensus established.")
            break
        else:
            logging.info("Consensus not established yet. Waiting 10 seconds")
            time.sleep(10)

if __name__ == '__main__':
    logging.info(40 * '-')
    logging.info('Nimiq validator activation script')
    logging.info(40 * '-')
    parser = argparse.ArgumentParser(description='Activate Validator')
    parser.add_argument('--version', type=str, default='master', help='The version of the repo branch to use (master or dev)')
    parser.add_argument('--network', type=str, default='testnet', help='The network to use (testnet or mainnet)')
    args = parser.parse_args()
    install_validator(args.version, args.network)
    check_block_height()
    activate_validator()
    
