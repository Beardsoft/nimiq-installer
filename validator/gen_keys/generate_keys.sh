#!/bin/bash

# Define the output directory, assumed to be a mounted volume
output_dir="/keys"

# Function to generate a Nimiq address
function generate_nimiq_address() {
    local output_file="$output_dir/$1"
    # Check if the file already exists
    if [ -f "$output_file" ]; then
        echo "Key file $output_file already exists. Skipping generation."
    else
        echo "Generating Nimiq address and saving to $output_file..."
        nimiq-address > $output_file 2>/dev/null
    fi
}

# Function to generate a Nimiq BLS key
function generate_nimiq_bls() {
    local output_file="$output_dir/$1"
    # Check if the file already exists
    if [ -f "$output_file" ]; then
        echo "Key file $output_file already exists. Skipping generation."
    else
        echo "Generating Nimiq BLS key and saving to $output_file..."
        nimiq-bls > $output_file 2>/dev/null
    fi
}

# Generate the different keys
generate_nimiq_address "address.txt"
generate_nimiq_address "fee_key.txt"
generate_nimiq_address "signing_key.txt"
generate_nimiq_bls "vote_key.txt"

echo "Key generation completed."
