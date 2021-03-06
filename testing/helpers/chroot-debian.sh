#!/bin/bash

cat << EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian buster main contrib
deb-src http://deb.debian.org/debian buster main contrib
EOF

cat << EOF > /etc/apt/sources.list.d/buster-backports.list
deb http://deb.debian.org/debian buster-backports main contrib
deb-src http://deb.debian.org/debian buster-backports main contrib
EOF

apt-get update

cat << EOF > /etc/apt/preferences.d/90_zfs
Package: libnvpair1linux libuutil1linux libzfs2linux libzfslinux-dev libzpool2linux python3-pyzfs pyzfs-doc spl spl-dkms zfs-dkms zfs-dracut zfs-initramfs zfs-test zfsutils-linux zfsutils-linux-dev zfs-zed
Pin: release n=buster-backports
Pin-Priority: 990
EOF

# Prevent terminal stupidity and interactive prompts
export TERM=linux
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

apt-get install --yes locales console-setup ca-certificates openssh-{client,server}
dpkg-reconfigure -f noninteractive

# Make sure the kernel is installed and configured before ZFS
apt-get install --yes linux-{headers,image}-amd64
apt-get install --yes zfs-dkms zfsutils-linux zfs-initramfs

# Post-setup configuration
if [ -x /root/configure-debian.sh ]; then
  /root/configure-debian.sh
  rm /root/configure-debian.sh
fi
