#!/bin/bash

# Improved Nimiq V2 Installer with Repository Cloning and Monitoring

# Set default values
REPO_URL="https://github.com/maestroi/nimiq-installer.git"
REPO_DIR="/opt/nimiq-installer"
username="protocol"
protocol_uid=1001
network=${1:-testnet}
node_type=${2:-validator}
monitor=${3:-true} 
version=${4:-improvements}  # Specify branch or tag if needed

GEN_KEYS_DOCKER_IMAGE="ghcr.io/maestroi/nimiq-key-generator:main"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to display the startup banner
function print_banner() {
    echo -n $'\033[0;32m'
    echo $''
    echo $'     _  __ _         _         ____           __         __ __          '
    echo $'    / |/ /(_)__ _   (_)___ _  /  _/___   ___ / /_ ___ _ / // /___  ____ '
    echo $'   /    // //  " \ / // _ `/ _/ / / _ \ (_-</ __// _ `// // // -_)/ __/ '
    echo $'  /_/|_//_//_/_/_//_/ \_, / /___//_//_//___/\__/ \_,_//_//_/ \__//_/    '
    echo $'                       /_/                                              '
    echo $' \033[0m';
    echo -e "${BLUE}Installing Nimiq with node type $node_type on $network network.${NC}"
}

# Function to check if the script is running as root
function check_root() {
    if [[ $(id -u) -ne 0 ]]; then
        echo -e "${RED}This script must be run as root.${NC}"
        exit 1
    fi
}

# Function to check if the OS is Ubuntu
function check_os() {
    if [[ $(lsb_release -si) != "Ubuntu" ]]; then
        echo -e "${RED}This script is only compatible with Ubuntu.${NC}"
        exit 1
    fi
}
# Function to validate network and node type
function validate_inputs() {
    if [[ $network != "testnet" ]]; then
        echo -e "${RED}Invalid network parameter. Please use 'testnet'.${NC}"
        exit 1
    fi

    if [[ $node_type != "full_node" && $node_type != "validator" ]]; then
        echo -e "${RED}Invalid node_type parameter. Please use 'full_node' or 'validator'.${NC}"
        exit 1
    fi
}

function setup_firewall() {
    echo -e "${GREEN}Installing Firewall rules${NC}"
    # Allow SSH
    ufw allow 22/tcp &>/dev/null

    # Allow nimiq traffic
    ufw allow 8443/tcp &>/dev/null

    # Enable UFW
    ufw --force enable &>/dev/null
}

function install_docker() {
    echo -e "${GREEN}Installing Docker...${NC}"
    apt-get update &>/dev/null
    apt-get install -y docker.io docker-compose python3 python3-pip &>/dev/null
    docker network create app_net &>/dev/null
    if ! id -nG $username | grep -qw docker; then
        echo -e "${GREEN}Adding user $username to the docker group.${NC}"
        usermod -aG docker $username
    fi
    echo -e "${GREEN}Docker installation complete.${NC}"
}

function install_packages() {
    echo -e "${GREEN}Installing packages...${NC}"
    apt-get update &>/dev/null
    apt-get install -y curl jq libjq1 libonig5 git ufw fail2ban zip &>/dev/null
    echo -e "${GREEN}Package installation complete.${NC}"
}

# Function to clone the repository
function clone_repo() {
    echo -e "${GREEN}Cloning Nimiq installer repository...${NC}"
    git clone $REPO_URL $REPO_DIR --branch $version &>/dev/null
    cd $REPO_DIR
}

function setup_user() {
    # Create the protocol group with the specified GID (if it does not already exist)
    if ! getent group $protocol_uid &>/dev/null; then
        echo -e "${GREEN}Creating group: $protocol_uid.${NC}"
        groupadd -r -g $protocol_uid $username
    fi
    if ! id -u $username > /dev/null 2>&1; then
        echo -e "${GREEN}Creating user: $username with ID: $protocol_uid .${NC}"
        id -u $username &>/dev/null || useradd -r -m -u $protocol_uid -g $protocol_uid -s /usr/sbin/nologin $username
    fi

}

function zip_secrets() {
    zip -r /root/secrets.zip /opt/nimiq/validator/secrets &>/dev/null
    if [ $? -eq 0 ]; then
        echo "File /root/secrets.zip created successfully."
    else
        echo "Failed to create file /root/secrets.zip."
    fi
}

# Function to set up a full node
function setup_full_node() {
    echo -e "${GREEN}Setting up Nimiq Full Node...${NC}"

    # Define the configuration directory
    local config_dir="$REPO_DIR/full_node"

    # Navigate to the configuration directory
    cd $config_dir

    # Check if the network configuration file exists
    local config_file
    if [ "$network" == "testnet" ]; then
        config_file="${config_dir}/testnet-config.toml"
    elif [ "$network" == "mainnet" ]; then
        config_file="${config_dir}/mainnet-config.toml"
    else
        echo -e "${RED}Invalid network parameter. Only 'testnet' and 'mainnet' are supported.${NC}"
        exit 1
    fi

    if [ ! -f "$config_file" ]; then
        echo -e "${RED}Configuration file for $network not found.${NC}"
        exit 1
    fi

    # Copy the configuration file to a working directory
    local work_dir="/opt/nimiq/full_node"
    mkdir -p $work_dir
    cp $config_file "${work_dir}/client.toml"

    # Copy Docker-compose file
    cp "${config_dir}/Docker-compose.yaml" "${work_dir}/docker-compose.yaml"

    # Copy Nginx configuration file if it exists
    if [ -f "${config_dir}/nginx.conf" ]; then
        cp "${config_dir}/nginx.conf" "${work_dir}/nginx.conf"
    fi

    # Navigate to the working directory and start the Docker container
    cd $work_dir
    echo -e "${GREEN}Starting the Nimiq Full Node Docker container...${NC}"

    # Allow HTTP and HTTPS traffic
    ufw allow 80/tcp &>/dev/null
    ufw allow 443/tcp &>/dev/null

    docker-compose up -d &>/dev/null

    echo -e "${GREEN}Nimiq Full Node setup complete.${NC}"
}

# Function to set up a validator node
function setup_validator_node() {
    echo -e "${GREEN}Setting up Nimiq Validator Node...${NC}"

    # Define the configuration directory
    local config_dir="$REPO_DIR/validator"

    # Navigate to the configuration directory
    cd $config_dir

    # Check if the network configuration file exists
    local config_file
    if [ "$network" == "testnet" ]; then
        config_file="${config_dir}/testnet-config.toml"
    elif [ "$network" == "mainnet" ]; then
        config_file="${config_dir}/mainnet-config.toml"
    else
        echo -e "${RED}Invalid network parameter. Only 'testnet' and 'mainnet' are supported.${NC}"
        exit 1
    fi

    if [ ! -f "$config_file" ]; then
        echo -e "${RED}Configuration file for $network not found.${NC}"
        exit 1
    fi

    # Copy the configuration file to a working directory
    local work_dir="/opt/nimiq/validator"
    mkdir -p $work_dir
    cp $config_file "${work_dir}/client.toml"

    # Copy Nginx configuration file if it exists
    if [ -f "${config_dir}/nginx.conf" ]; then
        cp "${config_dir}/nginx.conf" "${work_dir}/nginx.conf"
    fi

    # Create the secrets directory
    mkdir -p "${work_dir}/secrets"

    # Generate the validator key if it doesn't exist
    docker run --rm -v "${work_dir}/secrets:/keys" -u 0 ${GEN_KEYS_DOCKER_IMAGE} &>/dev/null
    
    # Define file paths for the keys
    local address="${work_dir}/secrets/address.txt"
    local fee_key="${work_dir}/secrets/fee_key.txt"
    local signing_key="${work_dir}/secrets/signing_key.txt"
    local vote_key="${work_dir}/secrets/vote_key.txt"
    local configuration_file="${work_dir}/client.toml"

    # Read values from secret files
    ADDRESS=$(cat $address | sed -n 's/Address:[[:space:]]*\(.*\)/\1/p')
    ADDRESS_PRIVATE=$(grep "Private Key:" $address | awk '{print $3}')
    FEE_KEY=$(grep "Private Key:" $fee_key | awk '{print $3}')
    SIGNING_KEY=$(grep "Private Key:" $signing_key | awk '{print $3}')
    VOTING_KEY=$(awk '/Secret Key:/{getline; getline; print}' $vote_key)

    # Update client.toml
    sed -i "s/CHANGE_VALIDATOR_ADDRESS/$ADDRESS/g" $configuration_file
    sed -i "s/CHANGE_FEE_KEY/$ADDRESS_PRIVATE/g" $configuration_file
    sed -i "s/CHANGE_SIGN_KEY/$SIGNING_KEY/g" $configuration_file
    sed -i "s/CHANGE_VOTE_KEY/$VOTING_KEY/g" $configuration_file

    # Zipping secrets
    echo -e "${GREEN}Zipping secrets...${NC}"
    zip_secrets 

    # Copy Docker-compose file and other necessary files
    cp "${config_dir}/Docker-compose.yaml" "${work_dir}/docker-compose.yaml"

    # Navigate to the working directory
    cd $work_dir

    # Start the Docker container
    echo -e "${GREEN}Starting the Nimiq Validator Node Docker container...${NC}"
    docker-compose up -d &>/dev/null

    echo -e "${GREEN}Nimiq Validator Node setup complete.${NC}"
}

# Function to install and configure monitoring tools
function setup_monitoring() {
    echo -e "${GREEN}Setting up monitoring tools...${NC}"

    # Define the source directory where monitoring files are located in the repo
    local monitor_source_dir="$REPO_DIR/monitor"

    # Define the target directory for the monitoring setup
    local monitor_target_dir="/opt/monitor"

    # Create the target directory if it doesn't exist
    mkdir -p $monitor_target_dir

    # Copy the monitoring configuration files to the target directory
    cp -r ${monitor_source_dir}/* $monitor_target_dir

    # Get the public IP address
    public_ip=$(curl -s https://api.ipify.org)

    # Replace the placeholder in docker-compose.yml with the actual IP
    sed -i "s/REPLACE_IP_HERE/$public_ip/g" $monitor_target_dir/docker-compose.yml

    # Navigate to the target monitoring directory and start the services
    cd $monitor_target_dir
    docker-compose up -d &>/dev/null

    echo -e "${GREEN}Monitoring setup completed successfully.${NC}"
    echo -e "${GREEN}Wait few seconds before grafana is ready${NC}"
    sleep 15
    echo -e "${GREEN}Monitoring setup completed successfully.${NC}"
    echo -e "${YELLOW}Login with Username: admin and Password: nimiq.${NC}"
    echo -e "${YELLOW}Change password to a secure password!${NC}"
    echo -e "${GREEN}Grafana is running at: http://$public_ip/grafana${NC}"

}


# Function to execute the main installation process
function main() {
    print_banner
    check_root
    check_os
    validate_inputs
    setup_firewall
    clone_repo
    setup_user
    install_docker
    install_packages

    if [ "$node_type" == "full_node" ]; then
        setup_full_node
    elif [ "$node_type" == "validator" ]; then
        setup_validator_node
    else
        echo -e "${RED}Invalid node_type parameter. Please use 'full_node' or 'validator'.${NC}"
        exit 1
    fi

    if [ "$monitor" == "true" ]; then
        setup_monitoring
    else
        echo -e "${YELLOW}Monitoring setup skipped.${NC}"
    fi    

    echo -e "${GREEN}Nimiq V2 installation and monitoring setup completed successfully.${NC}"
}

# Start the main function
main
