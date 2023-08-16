#!/bin/sh
# vim: softtabstop=2 shiftwidth=2 expandtab

# Install extra packages
apk add linux-lts-zfs-bin bash dhcpcd openssh

# Enable services
ln -s /etc/dinit.d/agetty-ttyS0 /etc/dinit.d/boot.d/
ln -s /etc/dinit.d/dhcpcd /etc/dinit.d/boot.d/
ln -s /etc/dinit.d/sshd /etc/dinit.d/boot.d/

# switch to a shell that isn't stuck in the 80s
chsh -s /bin/bash

# Set root password
echo 'root:zfsbootmenu' | chpasswd -c SHA256

# Configure the system to create a recursive snapshot every boot
cat << 'EOF' > /etc/rc.local
for _pool in "$( zpool list -o name -H 2>/dev/null )"; do
  zfs snapshot -r "${_pool}@$(date +%m%d%Y-%H%M)"
done
EOF

chmod +x /etc/rc.local

cat << 'EOF' > /usr/share/initramfs-tools/hooks/zfsencryption
if [ "$1" = "prereqs" ]; then
  exit 0
fi

. /usr/share/initramfs-tools/hook-functions

[ -d "${DESTDIR}/etc/zfs" ] || mkdir "${DESTDIR}/etc/zfs"

for keyfile in /etc/zfs/*.key; do
  [ -e "${keyfile}" ] || continue
  cp "${keyfile}" "${DESTDIR}/etc/zfs/"
done
EOF
chmod +x /usr/share/initramfs-tools/hooks/zfsencryption

# Refresh initramfs
update-initramfs -c -k all

# Restore resolv.conf
rm /etc/resolv.conf
mv /etc/resolv.conf.orig /etc/resolv.conf
