# Use the specified image as the base
FROM maestroi/nimiq-albatross:stable

# Copy the key generation script to the container
COPY generate_keys.sh /usr/local/bin/generate_keys.sh

# Set the script as the entrypoint
ENTRYPOINT ["bash", "/usr/local/bin/generate_keys.sh"]
