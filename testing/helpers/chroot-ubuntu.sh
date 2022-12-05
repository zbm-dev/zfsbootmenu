#!/bin/bash

: "${RELEASE:=jammy}"
: "${APT_REPOS:=main restricted universe multiverse}"

cat << EOF > /etc/apt/sources.list
deb http://us.archive.ubuntu.com/ubuntu ${RELEASE} ${APT_REPOS}
deb-src http://us.archive.ubuntu.com/ubuntu ${RELEASE} ${APT_REPOS}
EOF

cat << EOF > /etc/apt/sources.list.d/${RELEASE}-backports.list
deb http://us.archive.ubuntu.com/ubuntu ${RELEASE}-backports ${APT_REPOS}
deb-src http://us.archive.ubuntu.com/ubuntu ${RELEASE}-backports ${APT_REPOS}
EOF

apt-get update

# Prevent terminal stupidity and interactive prompts
export TERM=linux
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

apt-get install --yes bsdextrautils \
	locales console-setup ca-certificates openssh-{client,server}
dpkg --configure -a

# Make sure the kernel is installed and configured before ZFS
# Don't allow the kernel to pull in recommended packages (including GRUB)
apt-get install --yes --no-install-recommends linux-image-generic initramfs-tools
apt-get install --yes zfsutils-linux zfs-initramfs

# Post-setup configuration
if [ -x /root/configure-ubuntu.sh ]; then
  /root/configure-ubuntu.sh
  rm /root/configure-ubuntu.sh
fi
