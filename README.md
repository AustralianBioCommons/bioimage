# BioImage
This repository is designed to build a bioimage (based on Ubuntu) and manage instances on NCI Nirin (OpenStack) platform (https://cloud.nci.org.au/).

----------------------------
## Table of Contents
----------------------------
* [Installation](#installation)
* [Environment](#environment)
    * [Setup](#setup)
    * [Activation](#activation)
* [Build Image](#build-image)
* [Instances Management](#instances-management)
    * [Create Instances and Boot Image](#create-instances-and-boot-image)
    * [Shut Down and Restart Instances](#shut-down-and-restart-the-instances)
* [Users Access](#users-access)
    * [Single User for Each Instance](#single-user-for-each-instance)
    * [Multiple Users for Each Instance](#multiple-users-for-each-instance)

## Installation

To get started, launch an Ubuntu instance as the control host and download this repository. Ensure the machine has access to OpenStack.
```
git clone https://github.com/eileen-xue/bioimage.git
cd bioimage
```

## Environment

### Setup
Install the required tools: Packer, Ansible, OpenStack CLI. Then, download your OpenStack RC file `[project_id]-openrc.sh` from NCI Cloud Web Portal.

Run the setup script to install dependencies and configure the environment:
```
./setup.sh
```

### Activation
Activate the environment before building images, managing instances, or configuring users:
```
source openstack_cli/bin/activate
source [project_id]-openrc.sh
```

## Build Image

### Step 1: Verify Packer Configuration
Navigate to the `build` directory and initialize the Packer plugins:
```
cd bioimage/build
packer init .
```

### Step 2: Build the BioImage
Run the following command to build the bioimage:
```
packer build openstack-bioimage.pkr.hcl
```

### Step 3: Verify the Built Image
After the build process is complete, verify the newly created image by running:
```
openstack image list | grep bioimage
```
The image should include the following applications:
- Singularity
- SHPC
- Spack
- Ansible
- Jupyter Notebook
- RStudio
- Nextflow
- Snakemake
- CVMFS client

You can check available applications using:
```
module avail
```

To use an application, load it with:
```
module load <app>
```

## Instances Management

### Create Instances and Boot Image
Since the image size is large, it is recommended to create bootable volumes first, then create instances from those volumes. Use the NCI Cloud Dashboard to create volumes and assign them a consistent prefix (e.g., `training-VM-1`, `training-VM-2`, etc.).

To create and start instances with the volumes:
```
cd bioimage/manage
./openstack/create-instances.sh <key-pair> <VM-prefix>
```

### Shut Down and Restart Instances
Stop instances when they are not in use and restart them as needed.
```
./openstack/instances-start.sh <VM-prefix>
./openstack/instances-stop.sh <VM-prefix>
```

## Users Access 

### Single User for Each Instance

#### Step 1: Generate passwords and Update IP Information
Generate passwords for each user and update the inventory file with the password and instance IPs.
```
cd bioimage/manage
python3 python/update-IP.py <VM-prefix> <project-id>
python3 python/update-keys.py <VM-prefix>
```

#### Step 2: Create Users and Enable Password Access
Add the `training` user with the generated passwords and enable password access.
```
ansible-playbook ./ansible/users-create-1-1.yml
ansible-playbook ./ansible/ssh-password-enable.yml
```

#### Step 3: Associate Floating IPs and Save VM Information
Create and associate floating IPs with the instances for public access. Save the username, password and public IP information in the `VMs` folder.
```
./openstack/floating-IP-create.sh <VM-prefix>
python3 python/list-VM-info.py <VM-prefix>
```

#### Step 4: Delete Users, Disable Password and Public IP Access
After the training session, delete the `training` user accounts, disable password access and disacciate public IP.
```
ansible-playbook ./ansible/users-delete.yml
ansible-playbook ./ansible/ssh-password-disable.yml
./openstack/floating-IP-delete.sh <VM-prefix>
```

#### Step 5: Optional – Shut Down the Instances
Shut down the instances when they are not in use. 
```
./openstack/instances-stop.sh <VM-prefix>
```

### Multiple Users for Each Instance
When multiple users need to share the same instance, follow these steps:

#### Step 1: Step 1: Generate passwords and Update IP Information
Manually specify the number of users and generate their passwords.

1. Generate password keys:
```
cd bioimage/manage
python3 python/generate-keys.py
```

Update the file `host_vars/[VM-name].yml` with the generated passwords. Sample files are provided.

2. Rename the inventory file and update IPs:
Rename the `inventory.n` file to `invenroty` and run the command:
```
python3 python/update-IP.py <VM-prefix> <project-id>
```

#### Step 2: Create Users and Enable Password Access
Create all the users and enable password access for them:
```
ansible-playbook ./ansible/users-create-n-1.yml
ansible-playbook ./ansible/ssh-passwords-enable.yml
```

#### Step 3: Associate Floating IPs and Save VM Information
Create and associate floating IPs with the instances for public access. 
```
./openstack/floating-IP-create.sh <VM-prefix>
```

#### Step 4: Delete Users and Disable Password and Public IP Access
After the training session, remove user accounts, disable password access.
```
ansible-playbook ./ansible/users-delete-all.yml
ansible-playbook ./ansible/ssh-password-disable.yml
```

#### Step 5: Optional – Shut Down the Instances
Shut down the instances when they are not in use. 
```
./openstack/instances-stop.sh <VM-prefix>
```