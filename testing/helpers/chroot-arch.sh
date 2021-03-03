#!/bin/sh
# vim: softtabstop=2 shiftwidth=2 expandtab

# Configure a default locale
cat << EOF >> /etc/locale.gen
en_US.UTF-8 UTF-8
en_US ISO-8859-1
EOF

locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "archzfs" > /etc/hostname
cat << EOF >> /etc/hosts
127.0.0.1 localhost
::1 localhost
EOF

# Set root password
echo 'root:zfsbootmenu' | chpasswd -c SHA256

# Enable networking in the system
mkdir -p /etc/systemd/network
cat << EOF >> /etc/systemd/network/20-wired.network
[Match]
Name=en*
[Network]
DHCP=yes
EOF

rm -f /etc/resolv.conf
systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service

# enable root login over ssh with a password
if [ -f /etc/ssh/sshd_config ]; then
  sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
fi

systemctl enable sshd.service

ZFILES="/etc/hostid"
for keyfile in /etc/zfs/*.key; do
  [ -e "${keyfile}" ] && ZFILES="${ZFILES} ${keyfile}"
done

sed -e "/HOOKS=/s/fsck/zfs/" -e "/FILES=/s@)@${ZFILES})@" -i /etc/mkinitcpio.conf

# Arch doesn't play nicely with the pre-existing cache
rm -f /etc/zfs/zpool.cache
mkinitcpio -p linux
