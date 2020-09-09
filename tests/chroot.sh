#!/bin/sh

cat << EOF >> /etc/rc.conf
KEYMAP="us"
TIMEZONE="America/Chicago"
HARDWARECLOCK="UTC"
EOF

cat << EOF >> /etc/default/libc-locales
en_US.UTF-8 UTF-8
en_US ISO-8859-1
EOF
xbps-reconfigure -f glibc-locales

xbps-install -S
xbps-install -y linux5.8 zfs

#zpool set cachefile=/etc/zfs/zpool.cache ztest

cat << EOF > /etc/dracut.conf.d/zol.conf
nofsck="yes"
add_dracutmodules+=" zfs "
omit_dracutmodules+=" btrfs "
EOF

xbps-reconfigure -f linux5.8

zfs set org.zfsbootmenu:commandline="spl_hostid=$( hostid ) ro quiet" ztest/ROOT

echo 'root:zfsbootmenu' | chpasswd -c SHA256
