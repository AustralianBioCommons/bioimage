#!/bin/bash

BASE_IMAGE_NAME="bioimage"
VOLUME_PREFIX="training-VM"
VOLUME_SIZE=20

# Check OpenStack CLI availability
if ! command -v openstack &> /dev/null; then
  echo "OpenStack CLI not found. Please load your OpenStack environment (e.g. 'source openrc.sh')"
  exit 1
fi

# Check if base image exists
if ! openstack image show "$BASE_IMAGE_NAME" &> /dev/null; then
  echo " Base image '$BASE_IMAGE_NAME' not found in OpenStack. Use 'openstack image list' to check."
  exit 1
fi

# Prompt for number of volumes
read -p "How many volumes do you want to create? " NUM_VOLUMES

# Validate number
if ! [[ "$NUM_VOLUMES" =~ ^[0-9]+$ ]] || [[ "$NUM_VOLUMES" -le 0 ]]; then
  echo "Invalid number: $NUM_VOLUMES"
  exit 1
fi

# Create each volume
for i in $(seq 1 $NUM_VOLUMES); do
  VOLUME_NAME="${VOLUME_PREFIX}-${i}"
  echo "Creating volume '$VOLUME_NAME' from image '$BASE_IMAGE_NAME'..."
  
  openstack volume create \
    --image "$BASE_IMAGE_NAME" \
    --size "$VOLUME_SIZE" \
    --bootable \
    "$VOLUME_NAME"

  if [[ $? -ne 0 ]]; then
    echo "Failed to create volume '$VOLUME_NAME'"
  fi
done

echo "Done. Created $NUM_VOLUMES volumes from '$BASE_IMAGE_NAME'"
