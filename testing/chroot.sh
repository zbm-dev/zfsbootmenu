#!/bin/sh

# Configure a default locale
cat << EOF >> /etc/default/libc-locales
en_US.UTF-8 UTF-8
en_US ISO-8859-1
EOF
xbps-reconfigure -f glibc-locales

# Install a kernel and ZFS
xbps-install -S
xbps-install -y linux5.8 zfs

# Setup ZFS in Dracut
cat << EOF > /etc/dracut.conf.d/zol.conf
nofsck="yes"
add_dracutmodules+=" zfs "
omit_dracutmodules+=" btrfs "
EOF

xbps-reconfigure -f linux5.8

# Set kernel commandline
zfs set org.zfsbootmenu:commandline="spl_hostid=$( hostid ) ro quiet" ztest/ROOT

# Configure the system to create a recursive snapshot every boot
cat << \EOF > /etc/rc.local
zfs snapshot -r ztest@$(date +%m%d%Y-%H%M)
EOF

# Set root password
echo 'root:zfsbootmenu' | chpasswd -c SHA256

# delete ourself
rm /root/chroot.sh

zfs snapshot -r ztest@full-setup

touch /root/IN_THE_MATRIX
zfs snapshot -r ztest@minor-changes
rm /root/IN_THE_MATRIX
