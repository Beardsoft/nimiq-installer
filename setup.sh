#!/bin/bash

# Improved Nimiq V2 Installer with Repository Cloning and Monitoring

# Set default values
REPO_URL="https://github.com/maestroi/nimiq-installer.git"
REPO_DIR="/opt/nimiq-installer"
network=${1:-testnet}
node_type=${2:-full_node}
version=${3:-improvements}  # Specify branch or tag if needed

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


# Function to clone the repository
function clone_repo() {
    echo -e "${GREEN}Cloning Nimiq installer repository...${NC}"
    git clone $REPO_URL $REPO_DIR --branch $version
    cd $REPO_DIR
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
    docker-compose up -d

    echo -e "${GREEN}Nimiq Full Node setup complete.${NC}"
}

# Function to set up a validator node
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

    # Copy Docker-compose file and other necessary files
    cp "${config_dir}/Docker-compose.yaml" "${work_dir}/docker-compose.yaml"
    cp "${config_dir}/activate_validator.py" "${work_dir}/activate_validator.py"
    cp "${config_dir}/requirements.txt" "${work_dir}/requirements.txt"
    cp "${config_dir}/nimiq-address.txt" "${work_dir}/"
    cp "${config_dir}/nimiq-bls.txt" "${work_dir}/"
    cp "${config_dir}/bls.txt" "${work_dir}/"

    # Navigate to the working directory
    cd $work_dir

    # Install any Python dependencies required for the validator activation script
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
    fi

    # Start the Docker container
    echo -e "${GREEN}Starting the Nimiq Validator Node Docker container...${NC}"
    docker-compose up -d

    # Activate the validator node if necessary
    if [ -f "activate_validator.py" ]; then
        echo -e "${GREEN}Activating the validator node...${NC}"
        python activate_validator.py --private-key=nimiq-address.txt
    fi

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

    # Navigate to the target monitoring directory and start the services
    cd $monitor_target_dir
    docker-compose up -d

    echo -e "${GREEN}Monitoring setup completed successfully.${NC}"
}


# Function to execute the main installation process
function main() {
    print_banner
    check_root
    check_os
    validate_inputs
    clone_repo

    if [ "$node_type" == "full_node" ]; then
        setup_full_node
    elif [ "$node_type" == "validator" ]; then
        setup_validator_node
    else
        echo -e "${RED}Invalid node_type parameter. Please use 'full_node' or 'validator'.${NC}"
        exit 1
    fi

    setup_monitoring

    echo -e "${GREEN}Nimiq V2 installation and monitoring setup completed successfully.${NC}"
}

# Start the main function
main
