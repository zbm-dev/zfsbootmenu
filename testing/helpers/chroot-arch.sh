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

# Space checks in pacman don't work right
sed -e "/CheckSpace/d" -i /etc/pacman.conf

pacman-key --init
pacman-key --populate

# Do this in two stages to avoid dracut providing the initramfs virtual
pacman --noconfirm -Sy linux linux-headers mkinitcpio vi openssh \
  fakeroot automake autoconf pkg-config gcc make libtool binutils curl
pacman --noconfirm -Sy dkms git dracut fzf kexec-tools cpanminus

# Install ZFS command-line utilities
runuser -u nobody -- /bin/sh -c "cd /tmp && \
  git clone --depth=1 https://aur.archlinux.org/zfs-utils.git && \
  cd zfs-utils && MAKEFLAGS='-j4' makepkg --skippgpcheck"
pacman -U --noconfirm /tmp/zfs-utils/*.pkg.*
rm -rf /tmp/zfs-utils

# Install ZFS DKMS module
runuser -u nobody -- /bin/sh -c "cd /tmp && \
  git clone --depth=1 https://aur.archlinux.org/zfs-dkms.git && \
  cd zfs-dkms && MAKEFLAGS='-j4' makepkg --skippgpcheck"
pacman -U --noconfirm /tmp/zfs-dkms/*.pkg.*
rm -rf /tmp/zfs-dkms

ZFILES="/etc/hostid"
for keyfile in /etc/zfs/*.key; do
  [ -e "${keyfile}" ] && ZFILES="${ZFILES} ${keyfile}"
done

sed -e "/HOOKS=/s/fsck/zfs/" -e "/FILES=/s@)@${ZFILES})@" -i /etc/mkinitcpio.conf

# The initcpio hook that ships with zfs-dkms do not support encryption
# Use the hook from archzfs instead
zfsutils="https://raw.githubusercontent.com/archzfs/archzfs/master/src/zfs-utils"
cpiolib="/usr/lib/initcpio"
curl -L -o "${cpiolib}/hooks/zfs" "${zfsutils}/zfs-utils.initcpio.hook"
curl -L -o "${cpiolib}/install/zfs" "${zfsutils}/zfs-utils.initcpio.install"
curl -L -o "${cpiolib}/install/zfsencryptssh" "${zfsutils}/zfs-utils.initcpio.zfsncrypt.sshinstall"

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

# Make sure gpg-agent components die to avoid blocking pool export
gpgconf --homedir /etc/pacman.d/gnupg --kill all
