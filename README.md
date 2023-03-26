# Nimiq installer

This repo is to have a automated installer for a nimiq validator or RPC node with full history.

Good to know is that it doesn't user permanent storage because Devnet is frequently restarted.

# Currently features
- full_node
- network switch
- auto-update
- port 80 on IP to JRPC port

# Oneliner
Be aware executing things directly in terminal as root, check the files first!

## Full node
```bash
curl -s https://raw.githubusercontent.com/maestroi/nimiq-installer/master/install_protocol.sh | bash -s devnet full_node
``` 

## Validator
```bash
curl -s https://raw.githubusercontent.com/maestroi/nimiq-installer/master/install_protocol.sh | bash -s devnet validator
``` 
# Use cloud-config
You can use the cloud config for any populair cloud provider to use for startup any node
