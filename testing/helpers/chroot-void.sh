#!/bin/sh
# vim: softtabstop=2 shiftwidth=2 expandtab

# Configure a default locale
cat << EOF >> /etc/default/libc-locales
en_US.UTF-8 UTF-8
en_US ISO-8859-1
EOF

# Update all packages
xbps-install -Suy xbps
xbps-install -uy

xbps-query glibc-locales >/dev/null 2>&1 && xbps-reconfigure -f glibc-locales
xbps-reconfigure -a

# Setup ZFS in Dracut
mkdir -p /etc/dracut.conf.d
cat << EOF > /etc/dracut.conf.d/zol.conf
nofsck="yes"
add_dracutmodules+=" zfs "
omit_dracutmodules+=" btrfs "
EOF

# Make sure any ZFS keyfiles are included
for keyfile in /etc/zfs/*.key; do
  [ -e "${keyfile}" ] || continue
  echo "install_items+=\" ${keyfile} \"" >> /etc/dracut.conf.d/zol.conf
done

xbps-install -y linux5.10 linux5.10-headers dracut zfs

# Set kernel commandline
case "$(uname -m)" in
  ppc64*)
    consoles="console=tty1 console=hvc0"
    ;;
  x86_64)
    consoles="console=tty1 console=ttyS0"
    ;;
esac

if [ -n "${ZBM_POOL}" ]; then
  cmdline="spl_hostid=$( hostid ) rw loglevel=4 ${consoles}"
  zfs set org.zfsbootmenu:commandline="${cmdline}" "${ZBM_POOL}/ROOT"
fi

# Configure the system to create a recursive snapshot every boot
cat << 'EOF' > /etc/rc.local
for _pool in "$( zpool list -o name -H 2>/dev/null )"; do
  zfs snapshot -r "${_pool}@$(date +%m%d%Y-%H%M)"
done
EOF

# Set root password
echo 'root:zfsbootmenu' | chpasswd -c SHA256

# enable services
ln -s /etc/sv/dhcpcd /etc/runit/runsvdir/default
ln -s /etc/sv/sshd /etc/runit/runsvdir/default
ln -s /etc/sv/agetty-ttyS0 /etc/runit/runsvdir/default
ln -s /etc/sv/agetty-hvc0 /etc/runit/runsvdir/default

# /bin/dash sucks
chsh -s /bin/bash

# enable root login over ssh with a password
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# Pre-install zfsbootmenu
if [ -x /root/zbm-populate.sh ]; then
  xbps-query -Rp run_depends zfsbootmenu | xargs xbps-install -y
  xbps-install -y git
  SKIP_PERL=yes /root/zbm-populate.sh
  rm /root/zbm-populate.sh
fi
