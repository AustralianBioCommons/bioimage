#!/bin/bash

# Check if OpenStack virtual environment is activated
# if [[ -z "$VIRTUAL_ENV" || "$VIRTUAL_ENV" != *"openstack_cli"* ]]; then
#     source openstack_cli/bin/activate
# else
#     echo "OpenStack virtual environment is already activated"
# fi

# # Check if OpenStack RC file is sourced
# if [[ -z "$OS_AUTH_URL" ]]; then
#     source [project-id]-openrc.sh
# else
#     echo "OpenStack RC file is already sourced"
# fi

# stop the server after 2min
# sleep 120  

# Check if name pattern is provided as an argument
if [ $# -eq 0 ]; then
    echo "Error: Please provide the name pattern as an argument."
    echo "Usage: $0 <name-pattern>"
    exit 1
fi

# Set the name pattern from the first argument, adding '^' at the beginning
NAME_PATTERN="^$1"

openstack server list --name "$NAME_PATTERN" -f value -c ID | xargs -n1 openstack server stop