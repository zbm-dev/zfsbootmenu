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
DBPath = ${PACROOT}/db
CacheDir = ${PACROOT}/cache
LogFile = ${PACROOT}/pacman.log
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

[archzfs]
Include = ${PACROOT}/zfsmirrors
EOF

cat >> "${PACROOT}/mirrorlist" << 'EOF'
Server = http://mirrors.mit.edu/archlinux/$repo/os/$arch
Server = http://mirror.cs.pitt.edu/archlinux/$repo/os/$arch
Server = http://mirror.arizona.edu/archlinux/$repo/os/$arch
Server = http://mirrors.rit.edu/archlinux/$repo/os/$arch
EOF

cat >> "${PACROOT}/zfsmirrors" << 'EOF'
Server = http://archzfs.com/$repo/x86_64
Server = http://mirror.sum7.eu/archlinux/archzfs/$repo/x86_64
Server = https://mirror.biocrafting.net/archlinux/archzfs/$repo/x86_64
Server = https://mirror.in.themindsmaze.com/archzfs/$repo/x86_64
Server = https://zxcvfdsa.com/archzfs/$repo/$arch
EOF

pacman-key --config "${PACROOT}/pacman.conf" --init

ARCHZFS_KEY=DDF7DB817396A49B2A2723F7403BD972F75D9D76
pacman-key --config "${PACROOT}/pacman.conf" -r "${ARCHZFS_KEY}"
pacman-key --config "${PACROOT}/pacman.conf" --lsign-key "${ARCHZFS_KEY}"

pacstrap() {
  yes | "${PACROOT}/arch-install-scripts/pacstrap" \
    -C "${PACROOT}/pacman.conf" "${CHROOT_MNT}" "$@"
}

# This is done in two stages to avoid dracut satisfying initramfs
pacstrap base archzfs-linux
pacstrap openssh vi git dracut fzf kexec-tools cpanminus gcc make

if [ -r "${ENCRYPT_KEYFILE}" ]; then
  mkdir -p "${CHROOT_MNT}/etc/zfs"
  cp "${ENCRYPT_KEYFILE}" "${CHROOT_MNT}/etc/zfs/"
fi

cp /etc/hostid "${CHROOT_MNT}/etc/"
cp /etc/resolv.conf "${CHROOT_MNT}/etc/"
cp "${PACROOT}/mirrorlist" "${CHROOT_MNT}/etc/pacman.d/"
cp "${PACROOT}/zfsmirrors" "${CHROOT_MNT}/etc/pacman.d/"

cat >> "${CHROOT_MNT}/etc/pacman.conf" << EOF
[archzfs]
Include = /etc/pacman.d/zfsmirrors
EOF

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
