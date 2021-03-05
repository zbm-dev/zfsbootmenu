#!/bin/bash

cat << EOF > /etc/apt/sources.list
deb http://us.archive.ubuntu.com/ubuntu focal main restricted universe multiverse
deb-src http://us.archive.ubuntu.com/ubuntu focal main restricted universe multiverse
EOF

cat << EOF > /etc/apt/sources.list.d/focal-backports.list
deb http://us.archive.ubuntu.com/ubuntu focal-backports main restricted universe multiverse
deb-src http://us.archive.ubuntu.com/ubuntu focal-backports main restricted universe multiverse
EOF

apt-get update

# Prevent terminal stupidity and interactive prompts
export TERM=linux
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

apt-get install --yes locales console-setup
dpkg-reconfigure -f noninteractive

# Make sure the kernel is installed and configured before ZFS
apt-get install --yes linux-image-generic openssh-{client,server}
apt-get install --yes zfsutils-linux zfs-initramfs

systemctl enable zfs.target
systemctl enable zfs-import-cache
systemctl enable zfs-mount
systemctl enable zfs-import.target

echo 'root:zfsbootmenu' | chpasswd -c SHA256

# Install components necessary for building ZFSBootMenu
if [ -x /root/zbm-populate.sh ]; then
  apt-get install --yes git dracut-core fzf kexec-tools cpanminus gcc make
  /root/zbm-populate.sh
  rm /root/zbm-populate.sh
fi

# Configure networking and ssh, clean up installation script
if [ -x /root/network-systemd.sh ]; then
  /root/network-systemd.sh
  rm /root/network-systemd.sh
fi

# Clean the cache and remove some build tools
apt-get autoremove
apt-get clean
