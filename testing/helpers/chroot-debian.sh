#!/bin/bash

: "${RELEASE:=bullseye}"
: "${APT_REPOS:=main contrib}"

cat << EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian ${RELEASE} ${APT_REPOS}
deb-src http://deb.debian.org/debian ${RELEASE} ${APT_REPOS}
EOF

apt-get update

# Prevent terminal stupidity and interactive prompts
export TERM=linux
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

apt-get install --yes bsdextrautils \
	locales console-setup ca-certificates openssh-{client,server}
dpkg-reconfigure -f noninteractive

# Make sure the kernel is installed and configured before ZFS
apt-get install --yes linux-{headers,image}-amd64
apt-get install --yes zfs-dkms zfsutils-linux zfs-initramfs

# Post-setup configuration
if [ -x /root/configure-debian.sh ]; then
  /root/configure-debian.sh
  rm /root/configure-debian.sh
fi
