# Nimiq installer

This repo is to have a automated installer for a nimiq validator or RPC node with full history.

Good to know is that it doesn't user permanent storage because Devnet is frequently restarted.

Mainnet is not yet available!

# Oneliner
Be aware executing things directly in terminal as root, check the files first!

## Full node
```bash
curl -s https://raw.githubusercontent.com/maestroi/nimiq-installer/master/install_protocol.sh | bash -s testnet full_node
``` 

## Validator
WIP
```bash
curl -s https://raw.githubusercontent.com/maestroi/nimiq-installer/master/install_protocol.sh | bash -s testnet validator
``` 
# Use cloud-config
You can use the cloud config for any populair cloud provider to use for startup any node
