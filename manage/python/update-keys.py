import string
import random
import re
import subprocess
import sys

def generate_password(length=36):
    """Generate a random password without problematic characters."""
    characters = string.ascii_letters + string.digits + "!@#$%^&*_+-=|:;,.?/"
    password = ''.join(random.choice(characters) for i in range(length))
    return password

def run_command(command):
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    return result.stdout.strip()

def get_vm_names(vm_prefix):
    """Get real instance names using list-IP.sh"""
    ip_list = run_command(f'./openstack/list-IP.sh {vm_prefix}')
    vm_names = []
    for line in ip_list.split('\n'):
        match = re.search(rf'\|\s+({re.escape(vm_prefix)}[-_]?\S+)\s+\|', line)
        if match:
            vm_names.append(match.group(1))
    return vm_names

def update_inventory(vm_prefix):
    # Get real instance names
    vm_names = get_vm_names(vm_prefix)
    num_vms = len(vm_names)

    # Read the current inventory
    with open('./inventory', 'r') as file:
        lines = file.readlines()

    # Process each line
    new_lines = []
    for line in lines:
        if re.match(rf'{re.escape(vm_prefix)}[-_]?\S+', line):
            parts = line.split()
            vm_name = parts[0]
            
            # Check if password exists
            if 'training_password=' not in line:
                new_password = generate_password()
                line = line.strip() + f' training_password="{new_password}"\n'
            
            # Check if IP address is missing
            if 'ansible_host=' not in line:
                line = re.sub(r'(\S+)', r'\1 ansible_host=', line, count=1)
            
            new_lines.append(line.strip() + '\n')

    # Add new VMs if needed
    current_vms = len(new_lines)
    for i in range(current_vms, num_vms):
        new_password = generate_password()
        new_line = f"{vm_names[i]} ansible_host= ansible_user=ubuntu training_password=\"{new_password}\"\n"
        new_lines.append(new_line)

    # Write the updated inventory
    with open('./inventory', 'w') as file:
        file.write("[training]\n")
        file.writelines(new_lines)

    print(f"Inventory updated with {num_vms} VMs.")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 update_keys.py <VM-prefix>")
        sys.exit(1)
    
    vm_prefix = sys.argv[1]
    update_inventory(vm_prefix)
