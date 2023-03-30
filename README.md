# Nimiq installer

This repo is to have a automated installer for a nimiq validator or RPC node with full history.

Good to know is that it doesn't user permanent storage because Devnet is frequently restarted.

Mainnet is not yet available!

# Hardware requirements
These are based on testnet requirements early on, disk might need be bigger later!

## Minimum
- CPU: 1 core
- Memory: 1 GB
- Disk: 20 GB HDD/SSD
- OS: Ubuntu 20.04+

## Recommended
- CPU: 2 core
- Memory: 4 GB
- Disk: 80 GB HDD/SSD
- OS: Ubuntu 20.04+

# Oneliner
Be aware executing things directly in terminal as root, check the files first!

## Full node
```bash
curl -s https://raw.githubusercontent.com/maestroi/nimiq-installer/master/install_protocol.sh | bash -s testnet full_node
``` 

## Validator
Still sometimes activation can have some problems!

```bash
curl -s https://raw.githubusercontent.com/maestroi/nimiq-installer/master/install_protocol.sh | bash -s testnet validator
``` 
# Use cloud-config
make sure you tag validator or full noed
You can use the cloud config for any populair cloud provider to use for startup any node


# Made possible by Maestro and Acestaking
