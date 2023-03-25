#!/bin/bash

# Set default values
username="protocol"
protocol_uid=1001
network=${1:-devnet}
node_type=${2:-full_node}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -n $'\033[0;32m'
echo $''
echo $'     _  __ _         _         ____           __         __ __          '
echo $'    / |/ /(_)__ _   (_)___ _  /  _/___   ___ / /_ ___ _ / // /___  ____ '
echo $'   /    // //  " \ / // _ `/ _/ / / _ \ (_-</ __// _ `// // // -_)/ __/ '
echo $'  /_/|_//_//_/_/_//_/ \_, / /___//_//_//___/\__/ \_,_//_//_/ \__//_/    '
echo $'                       /_/                                              '
echo $' \033[0m';

# Check if the script is running as root
if [[ $(id -u) -ne 0 ]]; then
    echo -e "${YELLOW}This script must be run as root.${NC}"
    exit 1
fi

# Check if the OS is Ubuntu
if [[ $(lsb_release -si) != "Ubuntu" ]]; then
    echo -e "${YELLOW}This script is only compatible with Ubuntu.${NC}"
    exit 1
fi

# Create the protocol group with the specified GID (if it does not already exist)
if ! getent group $protocol_uid &>/dev/null; then
    echo -e "${GREEN}Creating group: $protocol_uid.${NC}"
    groupadd -r -g $protocol_uid $username
fi

# Check if the user protocol exists, and create it if it doesn't
if ! id -u $username > /dev/null 2>&1; then
    echo -e "${GREEN}Creating user: $username with ID: $protocol_uid .${NC}"
    id -u $username &>/dev/null || useradd -r -m -u $protocol_uid -g $protocol_uid -s /usr/sbin/nologin $username

fi

# Update and upgrade Ubuntu
echo -e "${GREEN}Updating and upgrading Ubuntu, may take a while....${NC}"
apt-get update &>/dev/null
apt-get upgrade -y &>/dev/null

# Install Docker and Docker Compose
echo -e "${GREEN}Installing Docker and Docker Compose.${NC}"
apt-get install -y docker.io docker-compose &>/dev/null

# Install some common packages
echo -e "${GREEN}Installing common packages.${NC}"
apt-get install -y curl git ufw fail2ban &>/dev/null

# Check if the protocol user is already in the docker group, and add it if it's not
if ! id -nG $username | grep -qw docker; then
    echo -e "${GREEN}Adding user $username to the docker group.${NC}"
    usermod -aG docker $username
fi

# Check if the directories already exist, and create them if they don't
if [ ! -d "/opt/nimiq/configuration" ]; then
    echo -e "${GREEN}Creating directory: /opt/nimiq/configuration.${NC}"
    mkdir -p /opt/nimiq/configuration
fi

if [ ! -d "/opt/nimiq/data" ]; then
    echo -e "${GREEN}Creating directory: /opt/nimiq/data.${NC}"
    mkdir -p /opt/nimiq/data
fi

if [ ! -d "/opt/nimiq/secrets" ]; then
    echo -e "${GREEN}Creating directory: /opt/nimiq/secrets.${NC}"
    mkdir -p /opt/nimiq/secrets
fi

# Download config files
if [ "$network" == "devnet" ]; then
    echo -e "${GREEN}Downloading config file: devnet-config.toml.${NC}"
    curl -s https://raw.githubusercontent.com/maestroi/nimiq-installer/master/config/devnet-config.toml -o /opt/nimiq/configuration/client.toml
elif [ "$network" == "testnet" ]; then
    echo -e "${GREEN}Downloading config file: testnet-config.toml.${NC}"
    curl -s https://raw.githubusercontent.com/maestroi/nimiq-installer/master/config/testnet-config.toml -o /opt/nimiq/configuration/client.toml
else
    echo -e "${YELLOW}Invalid network parameter. Please use devnet or testnet.${NC}"
    exit 1
fi

echo -e "${GREEN}Downloading Docker Compose file.${NC}"
curl -s https://raw.githubusercontent.com/maestroi/nimiq-installer/master/Docker-compose.yaml -o /opt/nimiq/configuration/docker-compose.yaml

echo -e "${GREEN}Downloading Docker Compose env file.${NC}"
curl -s https://raw.githubusercontent.com/maestroi/nimiq-installer/master/env_file -o /opt/nimiq/configuration/env_file

# Set permissions for the directories
echo -e "${GREEN}Setting permissions for directories.${NC}"
chown -R $protocol_uid:$protocol_uid /opt/nimiq/configuration /opt/nimiq/data /opt/nimiq/secrets
chmod -R 750 /opt/nimiq/configuration
chmod -R 755 /opt/nimiq/data
chmod -R 740 /opt/nimiq/secrets

#Set the RPC_ENABLED environment variable based on the node type
if [ "$node_type" == "full_node" ]; then
    rpc_enabled=true
elif [ "$node_type" == "validator" ]; then
    rpc_enabled=false
else
    echo -e "${YELLOW}Invalid node_type parameter. Please use full_node or validator.${NC}"
    exit 1
fi

# Update the env_file with the RPC_ENABLED variable
echo -e "${GREEN}Setting RPC_ENABLED environment variable.${NC}"
if [ "$rpc_enabled" == "true" ]; then
    sed -i 's/^RPC_ENABLED=./RPC_ENABLED=true/' /opt/nimiq/configuration/env_file
else
    sed -i 's/^RPC_ENABLED=./RPC_ENABLED=false/' /opt/nimiq/configuration/env_file
fi

# Add firewall rules to allow incoming traffic on ports 80, 22, and 8443
echo -e "${GREEN}Adding firewall rules.${NC}"
ufw --force enable &>/dev/null
ufw allow 80/tcp &>/dev/null
ufw allow 22/tcp &>/dev/null
ufw allow 8443/tcp &>/dev/null
ufw allow 8443/udp &>/dev/null
echo -e "${GREEN}UFW configured successfully.${NC}"

# Run the Docker container using Docker Compose
echo -e "${GREEN}Starting Docker container.${NC}"
cd /opt/nimiq/configuration && docker-compose up -d &>/dev/null
echo -e "${GREEN}-----------------${NC}"
echo -e "${GREEN}To restart containers navigate /opt/nimiq/configuration ${NC}"
echo -e "${GREEN}and run docker-compose restart ${NC}"
echo -e "${GREEN}Follow logs with docker-compose logs ${NC}"
echo -e "${GREEN}-----------------${NC}"

# Print a message indicating that the script has finished
echo -e "${GREEN}Leave a star at: https://github.com/maestroi/nimiq-installer ${NC}"
echo -e "${GREEN}The script has finished.${NC}"
