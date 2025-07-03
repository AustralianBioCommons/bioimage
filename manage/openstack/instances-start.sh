#!/bin/bash

# Check if name pattern is provided as an argument
if [ $# -eq 0 ]; then
    echo "Error: Please provide the name pattern as an argument."
    echo "Usage: $0 <name-pattern>"
    exit 1
fi

# Set the name pattern from the first argument, adding '^' at the beginning
NAME_PATTERN="^$1"

# Run the OpenStack command with the modified name pattern
openstack server list --name "$NAME_PATTERN" --status SHUTOFF -f value -c ID | xargs -n1 openstack server start


