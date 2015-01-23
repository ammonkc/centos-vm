#!/bin/bash -eux

echo '==> Configuring settings for vagrant'

SSH_USER=${SSH_USER:-vagrant}
SSH_USER_HOME=${SSH_USER_HOME:-/home/${SSH_USER}}
VAGRANT_INSECURE_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key"

# Packer passes boolean user variables through as '1', but this might change in
# the future, so also check for 'true'.
if [ "$INSTALL_VAGRANT_KEY" = "true" ] || [ "$INSTALL_VAGRANT_KEY" = "1" ]; then
  # Add vagrant user (if it doesn't already exist)
  if ! id -u $SSH_USER >/dev/null 2>&1; then
      echo '==> Creating ${SSH_USER}'
      /usr/sbin/groupadd $SSH_USER
      /usr/sbin/useradd $SSH_USER -g $SSH_USER -G wheel
      echo '==> Giving ${SSH_USER} sudo powers'
      echo "${SSH_USER}"|passwd --stdin $SSH_USER
      echo "${SSH_USER}        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers
  fi

  echo '==> Installing Vagrant SSH key'
  mkdir -pm 700 ${SSH_USER_HOME}/.ssh
  # https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub
  echo "${VAGRANT_INSECURE_KEY}" > $SSH_USER_HOME/.ssh/authorized_keys
  chmod 0600 ${SSH_USER_HOME}/.ssh/authorized_keys
  chown -R ${SSH_USER}:${SSH_USER} ${SSH_USER_HOME}/.ssh
fi

echo '==> Recording box config date'
date > /etc/box_build_time

echo '==> Customizing message of the day'
echo 'Welcome to your Entropy virtual machine.' > /etc/motd

# Disable static motd
# sed -i 's/#PrintMotd yes/PrintMotd no/g' /etc/ssh/sshd_config
# install motd.sh
cat << 'EOF' > /etc/profile.d/motd.sh
#!/bin/bash

echo -e "
                _
               | |
      ___ _ __ | |_ _ __ ___  _ __  _   _
     / _ \ '_ \| __| '__/ _ \| '_ \| | | |
    |  __/ | | | |_| | | (_) | |_) | |_| |
     \___|_| |_|\__|_|  \___/| .__/ \__, |
                             | |     __/ |
                             |_|    |___/

################################################
Vagrant Box.......: ammonkc/entropy 2.1.0
hostname..........: `hostname`
IP Address........: `/sbin/ifconfig eth1 | grep 'inet addr' | awk -F: '{print $2}' | awk '{print $1}'`
OS Release........: `cat /etc/redhat-release`
kernel............: `uname -r`
User..............: `whoami`
Apache............: `httpd -v | grep version`
PHP...............: `php -v | grep cli`
Configured Sites..:

`cat /etc/hosts.dnsmasq`
################################################
"
EOF

chmod +x /etc/profile.d/motd.sh
