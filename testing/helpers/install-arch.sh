#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

cleanup () {
  if [ -n "${PACROOT}" ]; then
    # Tear down the root, first unmounting any special filesystems
    mounted=
    for fs in dev sys proc mnt; do
      if mountpoint -q "${PACROOT}/root.x86_64/${fs}"; then
        umount -R "${PACROOT}/root.x86_64/${fs}"

        # Make sure the mount succeeded
        if mountpoint -q "${PACROOT}/root.x86_64/${fs}"; then
          mounted=yes
        fi
      fi
    done

    if [ -z "${mounted}" ]; then
      rm -rf "${PACROOT}"
    fi

    unset PACROOT
  fi

  exit
}

if [ -z "${CHROOT_MNT}" ] || [ ! -d "${CHROOT_MNT}" ]; then
  echo "ERROR: chroot mountpoint must be specified and must exist"
  exit 1
fi

if ! PACROOT="$( mktemp -d )"; then
  echo "ERROR: cannot make directory to clone arch-install-scripts"
  exit 1
else
  export PACROOT
fi

trap cleanup EXIT INT TERM

MIRROR="https://mirrors.edge.kernel.org/archlinux/iso/latest"
PATTERN="archlinux-bootstrap-[-_.A-Za-z0-9]\+-x86_64\.tar\.zst"
if ! ./helpers/extract_remote.sh "${MIRROR}" "${PACROOT}" "${PATTERN}"; then
  echo "ERROR: could not fetch and extract Arch bootstrap image"
  exit 1
fi

PACSTRAP="${PACROOT}/root.x86_64"
if [ ! -d "${PACSTRAP}" ]; then
  echo "ERROR: did not find expected Arch bootstrap directory"
  exit 1
fi

# Space checks in pacman don't work right
sed -e "/CheckSpace/d" -i "${PACSTRAP}/etc/pacman.conf"

cat >> "${PACROOT}/mirrorlist" << 'EOF'
Server = http://mirrors.mit.edu/archlinux/$repo/os/$arch
Server = http://mirror.cs.pitt.edu/archlinux/$repo/os/$arch
Server = http://mirror.arizona.edu/archlinux/$repo/os/$arch
Server = http://mirrors.rit.edu/archlinux/$repo/os/$arch
EOF

mount --rbind "${CHROOT_MNT}" "${PACSTRAP}/mnt" && mount --make-rslave "${PACSTRAP}/mnt"
mount --rbind /dev "${PACSTRAP}/dev" && mount --make-rslave "${PACSTRAP}/dev"
mount -t sysfs sys "${PACSTRAP}/sys"
mount -t proc proc "${PACSTRAP}/proc"

cp "${PACROOT}/mirrorlist" "${PACSTRAP}/etc/pacman.d/"
cp "/etc/resolv.conf" "${PACSTRAP}/etc/"

# Configure pacstrap to use host cache as pacman cache
if [ -d "${CHROOT_MNT}/hostcache" ]; then
  sed -i  "${PACSTRAP}/etc/pacman.conf" \
    -e 's@var/cache/pacman/pkg@mnt/hostcache@g' -e 's/^#CacheDir/CacheDir/'
fi

unshare --fork --pid chroot "${PACSTRAP}" /bin/bash <<-EOF
trap 'gpgconf --homedir /etc/pacman.d/gnupg --kill all; exit' EXIT INT TERM
pacman-key --init
pacman-key --populate
pacstrap -c /mnt base
EOF

if [ -d "${CHROOT_MNT}/hostcache" ]; then
  # Use host cache as pacman cache
  sed -i "${CHROOT_MNT}/etc/pacman.conf" \
    -e 's@var/cache/pacman/pkg@hostcache@g' \ -e 's/^#CacheDir/CacheDir/'
fi

mkdir -p "${CHROOT_MNT}/etc"
cp /etc/hostid "${CHROOT_MNT}/etc/"
cp /etc/resolv.conf "${CHROOT_MNT}/etc/"

mkdir -p "${CHROOT_MNT}/etc/pacman.d"
cp "${PACROOT}/mirrorlist" "${CHROOT_MNT}/etc/pacman.d/"

# Add network configuration script
if [ -x ./helpers/network-systemd.sh ]; then
  mkdir -p "${CHROOT_MNT}/root"
  cp ./helpers/network-systemd.sh "${CHROOT_MNT}/root/"
fi

# Add ZFSBootMenu population script
if [ -x ./helpers/zbm-populate.sh ]; then
  mkdir -p "${CHROOT_MNT}/root"
  cp ./helpers/zbm-populate.sh "${CHROOT_MNT}/root/"
fi
