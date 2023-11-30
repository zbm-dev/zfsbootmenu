#!/bin/bash

systemctl enable zfs.target
systemctl enable zfs-import-cache
systemctl enable zfs-mount
systemctl enable zfs-import.target

echo 'root:zfsbootmenu' | chpasswd -c SHA256

# Install components necessary for building ZFSBootMenu
if [ -x /root/zbm-populate.sh ]; then
  apt-get install --yes --no-install-recommends \
    git dracut-core fzf kexec-tools cpanminus gcc make
  if [[ "$0" =~ "debian" ]]; then
    apt-get install --yes --no-install-recommends systemd-boot-efi
  fi
  /root/zbm-populate.sh
  rm /root/zbm-populate.sh
fi

# Configure networking and ssh, clean up installation script
if [ -x /root/network-systemd.sh ]; then
  /root/network-systemd.sh
  rm /root/network-systemd.sh
fi

# Remove build tools
apt-get --yes autoremove

# If not using /hostcache, clean the cache
[ -d /hostcache ] || apt-get clean
