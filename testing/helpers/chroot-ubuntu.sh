#!/bin/bash

cat << EOF > /etc/apt/sources.list
deb http://us.archive.ubuntu.com/ubuntu focal main restricted
deb-src http://us.archive.ubuntu.com/ubuntu focal main restricted
EOF

cat << EOF > /etc/apt/sources.list.d/focal-backports.list
deb http://us.archive.ubuntu.com/ubuntu focal-backports main restricted
deb-src http://us.archive.ubuntu.com/ubuntu focal-backports main restricted
EOF

apt-get update

# Prevent terminal stupidity and interactive prompts
export TERM=linux
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

apt-get install --yes locales
dpkg-reconfigure -f noninteractive

# Make sure the kernel is installed and configured before ZFS
apt-get install --yes linux-headers-generic linux-image-generic console-setup
apt-get install --yes zfsutils-linux zfs-initramfs

systemctl enable zfs.target
systemctl enable zfs-import-cache
systemctl enable zfs-mount
systemctl enable zfs-import.target

echo 'root:zfsbootmenu' | chpasswd -c SHA256
