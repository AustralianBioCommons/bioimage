import subprocess
import re
import sys

def run_command(command, vm_prefix):
    full_command = f"{command} {vm_prefix}"
    result = subprocess.run(full_command, shell=True, capture_output=True, text=True)
    return result.stdout.strip()

def update_inventory(vm_prefix, project_id):
    # Read the current inventory
    with open('./inventory', 'r') as file:
        inventory = file.readlines()

    # Run list-IP.sh and parse the output
    print("Running list-IP.sh...")
    ip_list = run_command('./openstack/list-IP.sh', vm_prefix)
    print("IP list output:")
    print(ip_list)
    vm_ips = {}
    for line in ip_list.split('\n'):
        match = re.search(rf'\|\s+({re.escape(vm_prefix)}-\d+)\s+\|\s+{re.escape(project_id)}=(\S+)\s+\|', line)
        if match:
            vm_name, ip = match.groups()
            vm_ips[vm_name] = ip
            print(f"Found VM: {vm_name} with IP: {ip}")

    print(f"VM IPs found: {vm_ips}")

    # Update the inventory file
    updated_inventory = []
    existing_vms = set()
    for line in inventory:
        if line.strip() == "[training]":
            updated_inventory.append(line)
            continue
        
        original_line = line
        for vm_name, ip in vm_ips.items():
            if vm_name in line:
                line = f"{vm_name} ansible_host={ip} ansible_user=ubuntu\n"
                existing_vms.add(vm_name)
                break  # Stop after updating the first match
        
        if line != original_line:
            print(f"Updated: {line.strip()}")
        else:
            print(f"Not updated: {line.strip()}")

        updated_inventory.append(line)

    # Add missing VMs
    for vm_name, ip in sorted(vm_ips.items()):
        if vm_name not in existing_vms:
            new_line = f"{vm_name} ansible_host={ip} ansible_user=ubuntu\n"
            updated_inventory.append(new_line)
            print(f"Added: {new_line.strip()}")

    # Write the updated inventory back to the file
    with open('./inventory', 'w') as file:
        file.writelines(updated_inventory)

    print("Inventory file updated with correct IP addresses and missing VMs added.")


def main():
    if len(sys.argv) != 3:
        print("Usage: python3 update-IP.py <VM-prefix> <project-id>")
        sys.exit(1)
    
    vm_prefix = sys.argv[1]
    project_id = sys.argv[2]
    update_inventory(vm_prefix, project_id)

if __name__ == "__main__":
    main()
