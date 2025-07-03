import os
import subprocess
import re
import sys
import csv

def run_command(command, vm_prefix):
    full_command = f"{command} {vm_prefix}"
    result = subprocess.run(full_command, shell=True, capture_output=True, text=True)
    return result.stdout.strip()

def get_vm_ips(vm_prefix):
    print("Listing IP addresses...")
    ip_list = run_command('./openstack/list-IP.sh', vm_prefix)
    vm_ips = {}
    for line in ip_list.split('\n'):
        match = re.match(rf'\|\s+({vm_prefix}-\d+)\s+\|\s+(\S+)(?:,\s+(\S+))?\s+\|', line)
        if match:
            vm_name, internal_ip, external_ip = match.groups()
            vm_ips[vm_name] = {'internal': internal_ip, 'external': external_ip}
    return vm_ips

def read_inventory(vm_prefix):
    with open('./inventory', 'r') as file:
        inventory = file.readlines()
    vm_info = {}
    for line in inventory:
        if line.startswith(f'{vm_prefix}-'):
            parts = line.split()
            vm_name = parts[0]
            vm_info[vm_name] = {'username': 'training'}
            password_match = re.search(r'training_password="([^"]+)"', line)
            if password_match:
                vm_info[vm_name]['password'] = password_match.group(1)
            else:
                vm_info[vm_name]['password'] = 'Password not found'
    return vm_info

def create_csv_file(vm_info, vm_ips, vm_prefix):
    host_folder = './VMs'
    if not os.path.exists(host_folder):
        os.mkdir(host_folder)
    
    # Create CSV filename with VM prefix
    csv_filename = os.path.join(host_folder, f"{vm_prefix}_VM_info.csv")
    
    # Get all VM names from both dictionaries
    all_vm_names = set(vm_info.keys()) | set(vm_ips.keys())
    
    # Write to CSV file
    with open(csv_filename, 'w', newline='', encoding='utf-8') as csvfile:
        fieldnames = ['VM_Name', 'Username', 'External_IP', 'Password']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        
        # Write header
        writer.writeheader()
        
        # Write data for each VM
        for vm_name in sorted(all_vm_names):
            row = {
                'VM_Name': vm_name,
                'Username': vm_info.get(vm_name, {}).get('username', 'Not found'),
                'External_IP': vm_ips.get(vm_name, {}).get('external', 'Not found'),
                'Password': vm_info.get(vm_name, {}).get('password', 'Not found')

            }
            writer.writerow(row)
    
    print(f"Created CSV file: {csv_filename}")
    print(f"Total VMs processed: {len(all_vm_names)}")

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 save-VM-info-csv.py <VM-prefix>")
        sys.exit(1)
    
    vm_prefix = sys.argv[1]
    vm_ips = get_vm_ips(vm_prefix)
    vm_info = read_inventory(vm_prefix)
    create_csv_file(vm_info, vm_ips, vm_prefix)

if __name__ == "__main__":
    main()