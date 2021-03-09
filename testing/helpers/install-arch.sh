#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

if [ -z "${CHROOT_MNT}" ] || [ ! -d "${CHROOT_MNT}" ]; then
  echo "ERROR: chroot mountpoint must be specified and must exist"
  exit 1
fi

if ! PACROOT="$( mktemp -d )"; then
  echo "ERROR: cannot make directory to clone arch-install-scripts"
  exit 1
fi

# shellcheck disable=SC2064
trap "rm -rf '${PACROOT}'" EXIT

( 
  cd "${PACROOT}" && \
  git clone --depth=1 https://git.archlinux.org/arch-install-scripts.git && \
  cd "${PACROOT}/arch-install-scripts" && make pacstrap 
)

mkdir -p "${PACROOT}"/{db,cache,gnupg,hooks}

cat >> "${PACROOT}/pacman.conf" << EOF
[options]
CacheDir = ${PACROOT}/cache
GPGDir = ${PACROOT}/gnupg
HookDir = ${PACROOT}/hooks
HoldPkg = pacman glibc
Architecture = auto

SigLevel = Never

[core]
Include = ${PACROOT}/mirrorlist

[extra]
Include = ${PACROOT}/mirrorlist

[community]
Include = ${PACROOT}/mirrorlist
EOF

cat >> "${PACROOT}/mirrorlist" << 'EOF'
Server = http://mirrors.mit.edu/archlinux/$repo/os/$arch
Server = http://mirror.cs.pitt.edu/archlinux/$repo/os/$arch
Server = http://mirror.arizona.edu/archlinux/$repo/os/$arch
Server = http://mirrors.rit.edu/archlinux/$repo/os/$arch
EOF

"${PACROOT}/arch-install-scripts/pacstrap" \
  -C "${PACROOT}/pacman.conf" "${CHROOT_MNT}" base

cp /etc/hostid "${CHROOT_MNT}/etc/"
cp /etc/resolv.conf "${CHROOT_MNT}/etc/"
cp "${PACROOT}/mirrorlist" "${CHROOT_MNT}/etc/pacman.d/"

if [ -r "${ENCRYPT_KEYFILE}" ]; then
  mkdir -p "${CHROOT_MNT}/etc/zfs"
  cp "${ENCRYPT_KEYFILE}" "${CHROOT_MNT}/etc/zfs/"
fi

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
