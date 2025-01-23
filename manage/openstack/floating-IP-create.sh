#!/bin/bash

# Check if the name pattern is provided as an argument
if [ $# -eq 0 ]; then
    echo "Error: Please provide the name pattern as an argument."
    echo "Usage: $0 <name-pattern>"
    exit 1
fi

# Set the name pattern from the first argument, adding '^' at the beginning
NAME_PATTERN="^$1"

INSTANCES=$(openstack server list --name "$NAME_PATTERN" -f value -c ID -c Name)

# openstack floating ip create external

while read -r INSTANCE_ID INSTANCE_NAME; do
  FLOATING_IP=$(openstack floating ip create external -f value -c floating_ip_address)
  openstack server add floating ip $INSTANCE_ID $FLOATING_IP
  echo "Assigned floating IP $FLOATING_IP to instance $INSTANCE_NAME"
done <<< "$INSTANCES"
