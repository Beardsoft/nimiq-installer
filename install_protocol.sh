#!/bin/bash

# Set default values
username="protocol"
network=${1:-devnet}
node_type=${2:-full_node}

# Check if the script is running as root
if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Check if the OS is Ubuntu
if [[ $(lsb_release -si) != "Ubuntu" ]]; then
    echo "This script is only compatible with Ubuntu."
    exit 1
fi

# Check if the user protocol exists, and create it if it doesn't
if ! id -u $username > /dev/null 2>&1; then
    useradd -m $username
fi

# Update and upgrade Ubuntu
apt-get update && apt-get upgrade -y

# Check if the protocol user is already in the docker group, and add it if it's not
if ! id -nG $username | grep -qw docker; then
    usermod -aG docker $username
fi

# Install Docker and Docker Compose
apt-get install -y docker.io docker-compose

# Install some common packages
apt-get install -y curl git vim

# Check if the directories already exist, and create them if they don't
if [ ! -d "/opt/nimiq/configuration" ]; then
    mkdir -p /opt/nimiq/configuration
fi

if [ ! -d "/opt/nimiq/data" ]; then
    mkdir -p /opt/nimiq/data
fi

if [ ! -d "/opt/nimiq/secrets" ]; then
    mkdir -p /opt/nimiq/secrets
fi

# Download config files
if [ "$network" == "devnet" ]; then
    curl -s https://raw.githubusercontent.com/maestroi/nimiq-installer/master/config/devnet-config.toml -o /opt/nimiq/configuration/config.toml
elif [ "$network" == "testnet" ]; then
    curl -s https://raw.githubusercontent.com/maestroi/nimiq-installer/master/config/testnet-config.toml -o /opt/nimiq/configuration/config.toml
else
    echo "Invalid network parameter. Please use devnet or testnet."
    exit 1
fi

curl -s https://raw.githubusercontent.com/maestroi/nimiq-installer/master/Docker-compose.yaml -o /opt/nimiq/configuration/docker-compose.yaml

# Set permissions for the directories
chown -R $username:docker /opt/nimiq/configuration /opt/nimiq/data /opt/nimiq/secrets
chmod -R 750 /opt/nimiq/configuration
chmod -R 755 /opt/nimiq/data
chmod -R 740 /opt/nimiq/secrets

# Set the RPC_ENABLED environment variable based on the node type
if [ "$node_type" == "full_node" ]; then
    rpc_enabled=true
elif [ "$node_type" == "validator" ]; then
    rpc_enabled=false
else
    echo "Invalid node_type parameter. Please use full_node or validator."
    exit 1
fi

# Create the environment file with the RPC_ENABLED variable
cat > /opt/nimiq/configuration/env_file <<EOF
RPC_ENABLED=$rpc_enabled
EOF

docker-compose -f /opt/nimiq/configuration/docker-compose.yaml up -d

# Print a message indicating that the script has finished
echo "The script has finished."
