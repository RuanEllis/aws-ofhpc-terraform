#cloud-config
preserve_hostname: false
fqdn: ${hostname}.${domain}
system_info:
  default_user:
    name: flight
ssh_authorized_keys:
  - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZq0QfzwAD9frBMARYbOuQhkcmZ0YcsfD64nAIkHb5nVDa9fN5ARTd93vMnMr51hktgoLWaxS2QCtskHecDsElQKbZsmBZGLehQi7k0G5F0kcMEhgVVJtwIkPvhn2lZdnoVx1UHt9l5psoMPKW7VXxwYmNyWUAEoNnb/mXQEsdJnSIou8JvHZOFqLSEj0wVUfx5ollT1FXdMAr34S1KPIf/KnNC0b6rk58k+rHq0TzVAmDWcT0xDd8KdHkP8B/ebdoyv05NOc+8BGvJuHjTXX+wnmOe/lP/pKCk1GmGU7mFpyb9x8algqg5JiEjWyh7okZmXx22+dn/bgLNQmE4iRP
runcmd:
  - cp ~flight/.ssh/authorized_keys ~/.ssh/authorized_keys
  - sed -i -e 's/#   StrictHostKeyChecking ask/StrictHostKeyChecking no/g' /etc/ssh/ssh_config