#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

cleanup() {
  if [ -n "${VOIDROOT}" ]; then
    rm -rf "${VOIDROOT}"
    unset VOIDROOT
  fi

  exit
}

if [ -z "${CHROOT_MNT}" ] || [ ! -d "${CHROOT_MNT}" ]; then
  echo "ERROR: chroot mountpoint must be specified and must exist"
  exit 1
fi

XBPS_ARCH="$(uname -m)"

if [[ "$0" =~ "musl" ]]; then
  XBPS_ARCH="${XBPS_ARCH}-musl"
  REPO_SUFFIX="/musl"
fi

export XBPS_ARCH

# Default repo for all official architectures
REPO="https://mirrors.servercentral.com/voidlinux/current"

# Custom overrrides for specific archictures
case "${XBPS_ARCH}" in
  aarch64*) REPO_SUFFIX="/aarch64" ;;
  *) ;;
esac

LIVE="${REPO/current/live}/current"
REPO="${REPO}${REPO_SUFFIX}"

PATTERN="void-${XBPS_ARCH}-ROOTFS-[-_.A-Za-z0-9]\+\.tar\.xz"
if ! ./helpers/extract_remote.sh "${LIVE}" "${CHROOT_MNT}" "${PATTERN}"; then
  echo "ERROR: could not fetch and extract Void bootstrap image"
  exit 1
fi

mkdir -p "${CHROOT_MNT}/etc/xbps.d"

cp /etc/hostid "${CHROOT_MNT}/etc/"
cp /etc/resolv.conf "${CHROOT_MNT}/etc/"
cp /etc/rc.conf "${CHROOT_MNT}/etc/"

echo "repository=${REPO}" > "${CHROOT_MNT}/etc/xbps.d/00-repository-main.conf"

# Use host cache if available
if [ -d "${CHROOT_MNT}/hostcache" ]; then
  echo "cachedir=/hostcache" > "${CHROOT_MNT}/etc/xbps.d/10-hostcache.conf"
fi

# Add ZFSBootMenu population script
if [ -x ./helpers/zbm-populate.sh ]; then
  mkdir -p "${CHROOT_MNT}/root"
  cp ./helpers/zbm-populate.sh "${CHROOT_MNT}/root/"
fi
