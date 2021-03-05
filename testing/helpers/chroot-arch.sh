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

ZFILES="/etc/hostid"
for keyfile in /etc/zfs/*.key; do
  [ -e "${keyfile}" ] && ZFILES="${ZFILES} ${keyfile}"
done

sed -e "/HOOKS=/s/fsck/zfs/" -e "/FILES=/s@)@${ZFILES})@" -i /etc/mkinitcpio.conf

# Arch doesn't play nicely with the pre-existing cache
rm -f /etc/zfs/zpool.cache
mkinitcpio -p linux

if [ -x /root/zbm-populate.sh ]; then
  # Arch installs cpanm in the vendor_perl subdirectory
  PATH="${PATH}:/usr/bin/site_perl:/usr/bin/vendor_perl" /root/zbm-populate.sh
  rm /root/zbm-populate.sh
fi

# Configure networking and ssh, clean up installation script
if [ -x /root/network-systemd.sh ]; then
  /root/network-systemd.sh
  rm /root/network-systemd.sh
fi
