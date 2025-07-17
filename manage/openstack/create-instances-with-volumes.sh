#!/bin/bash

# Check if both KEY_NAME and VM_PREFIX are provided as arguments
if [ $# -lt 2 ]; then
    echo "Error: Please provide both KEY_NAME and VM_PREFIX as arguments."
    echo "Usage: $0 <key-name> <vm-prefix>"
    exit 1
fi

# Set variables
FLAVOR="c3.2c4m10d"
KEY_NAME="$1"
VM_PREFIX="$2"
AVAILABILITY_ZONE="CloudV3"

# Get all volumes starting with the provided VM_PREFIX
VOLUMES=$(openstack volume list -f value -c ID -c Name -c Status | grep "$VM_PREFIX")

# Create instances for each available volume
while read -r VOLUME_ID VOLUME_NAME VOLUME_STATUS; do
  if [ "$VOLUME_STATUS" = "available" ]; then
    echo "Creating instance for volume $VOLUME_NAME (ID: $VOLUME_ID)"
    openstack server create \
      --flavor $FLAVOR \
      --security-group "ssh" \
      --volume $VOLUME_ID \
      --availability-zone "$AVAILABILITY_ZONE" \
      --key-name $KEY_NAME \
      --wait $VOLUME_NAME
  else
    echo "Skipping volume $VOLUME_NAME (ID: $VOLUME_ID). Current status: $VOLUME_STATUS"
  fi
done <<< "$VOLUMES"
