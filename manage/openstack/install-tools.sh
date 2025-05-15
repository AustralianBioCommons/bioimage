---
- name: Install tree package on OpenStack VMs
  hosts: training
  become: yes

  tasks:
    - name: Fix broken packages if needed
      shell: apt --fix-broken install -y
      register: fix_broken
      changed_when: "'0 upgraded, 0 newly installed' not in fix_broken.stdout"

    - name: Install tree package
      package:
        name: tree
        state: present