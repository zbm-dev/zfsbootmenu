#!/bin/sh
# vim: softtabstop=2 shiftwidth=2 expandtab

# Make sure APK knows where to find packages
cat <<EOF > /etc/apk/repositories
http://dl-cdn.alpinelinux.org/alpine/latest-stable/main/
https://dl-cdn.alpinelinux.org/alpine/latest-stable/main/
EOF

# Update all packages
apk update

# Add and enable ZFS tools
apk add linux-lts linux-lts-dev zfs zfs-lts bash

rc-update add zfs-import sysinit
rc-update add zfs-mount sysinit

# Enable DHCP and add SSH
apk add openssh
rc-update add sshd

cat > /etc/network/interfaces <<EOF
auto eth0
iface eth0 inet dhcp
EOF

# Make sure any ZFS keyfiles and ZFS modules are included in initramfs
for keyfile in /etc/zfs/*.key; do
  [ -e "${keyfile}" ] || continue
  echo "${keyfile}" >> /etc/mkinitfs/features.d/zfshost.files
done

echo "/etc/hostid" >> /etc/mkinitfs/features.d/zfshost.files
echo "/etc/zfs/zpool.cache" >> /etc/mkinitfs/features.d/zfshost.files

echo 'features="ata base keymap kms mmc scsi usb virtio zfs zfshost"' > /etc/mkinitfs/mkinitfs.conf
mkinitfs -c /etc/mkinitfs/mkinitfs.conf "$(ls /lib/modules)"

# Set kernel commandline
if [ -n "${ZBM_POOL}" ]; then
  cmdline="spl_hostid=$( hostid ) rw loglevel=4 console=tty1 console=ttyS0"
  zfs set org.zfsbootmenu:commandline="${cmdline}" "${ZBM_POOL}/ROOT"
fi

# Set root password
echo 'root:zfsbootmenu' | chpasswd -c SHA256

# /bin/ash sucks
sed -i '/^root/s@/bin/ash@/bin/bash@' /etc/passwd

# enable root login over ssh with a password
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# enable getty on serial port
sed -i 's/^#ttyS0::/ttyS0::/' /etc/inittab
grep -q ttyS0 /etc/securetty || echo ttyS0 >> /etc/securetty
