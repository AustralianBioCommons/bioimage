import os
import subprocess
import re
import sys

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

def create_host_files(vm_info, vm_ips):
    host_folder = './VMs'
    if os.path.exists(host_folder):
        for file in os.listdir(host_folder):
            os.remove(os.path.join(host_folder, file))
    else:
        os.mkdir(host_folder)

    for vm_name in set(vm_info.keys()) | set(vm_ips.keys()):
        filename = os.path.join(host_folder, f"{vm_name}.txt")
        with open(filename, 'w') as file:
            file.write(f"Username: {vm_info.get(vm_name, {}).get('username', 'Not found')}\n")
            file.write(f"Password: {vm_info.get(vm_name, {}).get('password', 'Not found')}\n")
            file.write(f"Public IP: {vm_ips.get(vm_name, {}).get('external', 'Not found')}\n")
        print(f"Created file for {vm_name}")

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 list-VM-info.py <VM-prefix>")
        sys.exit(1)
    
    vm_prefix = sys.argv[1]
    vm_ips = get_vm_ips(vm_prefix)
    vm_info = read_inventory(vm_prefix)
    create_host_files(vm_info, vm_ips)

if __name__ == "__main__":
    main()
