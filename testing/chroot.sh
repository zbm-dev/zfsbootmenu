#!/bin/sh

# Configure a default locale
cat << EOF >> /etc/default/libc-locales
en_US.UTF-8 UTF-8
en_US ISO-8859-1
EOF
xbps-reconfigure -f glibc-locales

# Install a kernel and ZFS
xbps-install -S
xbps-install -y linux5.9 linux5.9-headers zfs

# Setup ZFS in Dracut
cat << EOF > /etc/dracut.conf.d/zol.conf
nofsck="yes"
add_dracutmodules+=" zfs "
omit_dracutmodules+=" btrfs "
EOF

xbps-reconfigure -f linux5.9

# Set kernel commandline
case "$(uname -m)" in
  ppc64*)
    consoles="console=tty1 console=hvc0"
    ;;
  x86_64)
    consoles="console=tty1 console=ttyS0"
    ;;
esac

zfs set org.zfsbootmenu:commandline="spl_hostid=$( hostid ) ro quiet ${consoles}" ztest/ROOT

# Configure the system to create a recursive snapshot every boot
cat << \EOF > /etc/rc.local
zfs snapshot -r ztest@$(date +%m%d%Y-%H%M)
EOF

# Set root password
echo 'root:zfsbootmenu' | chpasswd -c SHA256

# enable services
ln -s /etc/sv/dhclient /etc/runit/runsvdir/default
ln -s /etc/sv/sshd /etc/runit/runsvdir/default
ln -s /etc/sv/agetty-ttyS0 /etc/runit/runsvdir/default
ln -s /etc/sv/agetty-hvc0 /etc/runit/runsvdir/default

# /bin/dash sucks
chsh -s /bin/bash

# enable root login over ssh with a password
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

zfs snapshot -r ztest@full-setup

touch /root/IN_THE_MATRIX
zfs snapshot -r ztest@minor-changes
rm /root/IN_THE_MATRIX

# delete ourself
rm /root/chroot.sh
