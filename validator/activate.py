#!/usr/bin/env python3 
import argparse
import json
import requests

# Request funds from faucet

faucet_url = "https://faucet.pos.nimiq-testnet.com/tapit"
rpc_url = "http://127.0.0.1:9100"

def send_faucet_request(faucet_url, address):
    data = {'address': address}
    headers = {'content-type': 'application/x-www-form-urlencoded'}
    response = requests.post(faucet_url, data=data, headers=headers)
    return response


def send_json_rpc(rpc_url, method, params):
    headers = {'content-type': 'application/json'}

    payload = {
        'jsonrpc': '2.0',
        'method': method,
        'params': params,
        'id': 1,
    }
    response = requests.post(rpc_url, data=json.dumps(payload), headers=headers).json()
    return response


def extract_nimiq_data():
    with open('nimiq-address.txt', 'r') as file:
        contents = file.read()

        # Extract the address
        address_line = [line for line in contents.split('\n') if line.startswith('Address:')][0]
        address = address_line.split(':')[1].strip()

        # Extract the raw address
        raw_address_line = [line for line in contents.split('\n') if line.startswith('Address (raw):')][0]
        raw_address = raw_address_line.split(':')[1].strip()

        # Extract the public key
        public_key_line = [line for line in contents.split('\n') if line.startswith('Public Key:')][0]
        public_key = public_key_line.split(':')[1].strip()

        # Extract the private key
        private_key_line = [line for line in contents.split('\n') if line.startswith('Private Key:')][0]
        private_key = private_key_line.split(':')[1].strip()

    return address, raw_address, public_key, private_key


def extract_public_key():
    with open('nimiq-bls.txt', 'r') as file:
        contents = file.read().replace('\n', '')

        # Find the line that contains "Public Key:"
        public_key_line = [line for line in contents.split('\n') if line.startswith('# Public Key:')]

        if not public_key_line:
            raise ValueError('Public Key line not found in file')

        # Extract the public key from the line
        #public_key = public_key_line[0].split('# Public Key:')[1].strip()
        public_key = public_key_line[0].split(':')[1].strip()[:-12]

    return public_key



if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Send a JSON-RPC message to a server.')
    #parser.add_argument('--url', type=str, required=True, help='The URL of the server to send the message to.')
    #parser.add_argument('--method', type=str, required=True, help='The name of the method to call.')
    #parser.add_argument('--params', type=json.loads, required=True, help='The parameters to pass to the method, in JSON format.')
    
    
    address, raw_address, public_key, private_key = extract_nimiq_data()    
    bls_public_key = extract_public_key()

    print(f"{address}")
    print(f"{raw_address}")
    print(f"{public_key}")
    print(f"{private_key}")
    print(f"{bls_public_key}")

    respons = send_json_rpc(rpc_url, "getAddress", '{"null": []}')
    print(respons)
    #args = parser.parse_args()

    #response = send_json_rpc(args.url, args.method, args.params)
    #print(response)
