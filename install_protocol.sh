#!/bin/bash

# Set default values
username=${1:-protocol}
docker_group=${2:-docker}

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
if ! id -nG $username | grep -qw $docker_group; then
    usermod -aG $docker_group $username
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

# Set permissions for the directories
chown -R $username:$username /opt/nimiq/configuration /opt/nimiq/data /opt/nimiq/secrets
chmod -R 750 /opt/nimiq/configuration
chmod -R 755 /opt/nimiq/data
chmod -R 740 /opt/nimiq/secrets

# Print a message indicating that the script has finished
echo "The script has finished."
