# Nimiq installer

This repo is to have a automated installer for a nimiq validator or RPC node with full node.

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
curl -s https://raw.githubusercontent.com/maestroi/nimiq-installer/master/setup.sh | bash -s testnet full_node
``` 

## Validator
Should be activating automatically on the next epoch, check grafana dashboard for logs.
Your validator address can be found in the grafana dashboard!

you can always check nimstats.com!

```bash
curl -s https://raw.githubusercontent.com/maestroi/nimiq-installer/master/setup.sh | bash -s testnet validator
``` 
# Use cloud-config
make sure you tag validator or full node
You can use the cloud config for any populair cloud provider to use for startup any node

# Monitoring
Login with admin/nimiq by default you can login with your own password after first login.
Url for your grafan instance will be http://YOURIP/grafana

We use the following components
- Prometheus
- Grafana
- Node exporter
- Loki
- Promtail

NOTE: You can switch off by setting the variable in the setup.sh file to false or 3rth variable to  false.


You can customize any alerts or settings to your liking.

# Made possible by Maestro and Acestaking
