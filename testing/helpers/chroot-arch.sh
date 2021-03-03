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

# enable root login over ssh with a password
if [ -f /etc/ssh/sshd_config ]; then
  sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
fi

ZFILES="/etc/hostid"
if [ -r "${ENCRYPT_KEYFILE}" ]; then
  ZFILES+=" ${ENCRYPT_KEYFILE}"
fi

sed -e "/HOOKS=/s/fsck/zfs/" -e "/FILES=/s@)@${ZFILES})@" -i /etc/mkinitcpio.conf
mkinitcpio -p linux
