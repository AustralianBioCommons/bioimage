#!/bin/bash

# Check if the name pattern is provided as an argument
if [ $# -eq 0 ]; then
    echo "Error: Please provide the name pattern as an argument."
    echo "Usage: $0 <name-pattern>"
    exit 1
fi

# Set the name pattern from the first argument, adding '^' at the beginning
NAME_PATTERN="^$1"

openstack server list --name "$NAME_PATTERN" -f value -c Name -c Networks | awk '{print $1, $NF}' | grep -oP '(\S+)\s+.*?(\d+\.\d+\.\d+\.\d+)' | sed "s/'//g" | while read instance ip; do
  echo "Removing floating IP $ip from instance $instance"
  openstack server remove floating ip $instance $ip
  echo "Deleting floating IP $ip"
  openstack floating ip delete $ip
done
