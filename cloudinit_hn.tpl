#cloud-config
preserve_hostname: false
fqdn: ${hostname}.${domain}
system_info:
  default_user:
    name: flight
ssh_authorized_keys:
  - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZq0QfzwAD9frBMARYbOuQhkcmZ0YcsfD64nAIkHb5nVDa9fN5ARTd93vMnMr51hktgoLWaxS2QCtskHecDsElQKbZsmBZGLehQi7k0G5F0kcMEhgVVJtwIkPvhn2lZdnoVx1UHt9l5psoMPKW7VXxwYmNyWUAEoNnb/mXQEsdJnSIou8JvHZOFqLSEj0wVUfx5ollT1FXdMAr34S1KPIf/KnNC0b6rk58k+rHq0TzVAmDWcT0xDd8KdHkP8B/ebdoyv05NOc+8BGvJuHjTXX+wnmOe/lP/pKCk1GmGU7mFpyb9x8algqg5JiEjWyh7okZmXx22+dn/bgLNQmE4iRP
ssh_keys:
  rsa_private: |
     <YOUR PRIVATE KEY HERE>
yum_repos:
  epel-release:
      baseurl: http://download.fedoraproject.org/pub/epel/7/$basearch
      enabled: true
      failovermethod: priority
      gpgcheck: true
      gpgkey: http://download.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7
      name: Extra Packages for Enterprise Linux 7 - Release
packages:
  - ansible
  - git      
runcmd:
  - systemctl stop firewalld && systemctl disable firewalld
  - iptables -F
  - cat /etc/ssh/ssh_host_rsa_key > ~/.ssh/id_rsa
  - chmod 600 ~/.ssh/id_rsa
  - cp ~flight/.ssh/authorized_keys ~/.ssh/authorized_keys
  - sed -i -e 's/#   StrictHostKeyChecking ask/StrictHostKeyChecking no/g' /etc/ssh/ssh_config
  - cat /tmp/ansible_nodes >> /etc/ansible/hosts
  - git clone https://github.com/openflighthpc/openflight-ansible-playbook /tmp/openflight-ansible-playbook
  - sed -i -e 's/gateway1/headnode1/g' /tmp/openflight-ansible-playbook/group_vars/all
  - cd /tmp/openflight-ansible-playbook && ansible-playbook openflight.yml
write_files:
  -   path: /etc/ansible/hosts
      permissions: '0644'
      owner: root:root
      content: |
        [gateway]
        ${hostname}
        [compute]
  -   encoding: b64
      path: /tmp/ansible_nodes
      permissions: '0644'
      owner: root:root
      content: ${nodelist}
