#!/bin/bash

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

# Create the user called protocol
useradd -m protocol

# Update and upgrade Ubuntu
apt-get update && apt-get upgrade -y

# Install Docker and Docker Compose
apt-get install -y docker.io docker-compose

# Add the protocol user to the docker group
usermod -aG docker protocol

# Install some common packages
apt-get install -y curl git vim

# Print a message indicating that the script has finished
echo "The script has finished."
