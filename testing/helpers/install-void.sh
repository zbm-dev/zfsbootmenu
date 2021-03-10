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
  ppc*) REPO="https://mirrors.servercentral.com/void-ppc/current" ;;
  *) ;;
esac

LIVE="${REPO/current/live}/current"
REPO="${REPO}${REPO_SUFFIX}"

PATTERN="void-${XBPS_ARCH}-ROOTFS-[-_.A-Za-z0-9]\+\.tar\.xz"
IMAGE="$( curl -L "${LIVE}" | \
  grep -o "${PATTERN}" | sort -Vr | head -n 1 | tr -d '\n' )"

if [ -z "${IMAGE}" ]; then
  echo "ERROR: cannot identify Void ROOTFS image"
  exit 1
fi

if ! VOIDROOT="$( mktemp -d )"; then
  echo "ERROR: cannot make temporary directory for Void installation"
  exit 1
else
  export VOIDROOT
fi

trap cleanup EXIT INT TERM

if ! curl -L -o "${VOIDROOT}/${IMAGE}" "${LIVE}/${IMAGE}"; then
  echo "ERROR: failed to fetch Void ROOTFS image"
  echo "Check URL at ${LIVE}/${IMAGE}"
  exit 1
fi

tar xf "${VOIDROOT}/${IMAGE}" -C "${CHROOT_MNT}"

mkdir -p "${CHROOT_MNT}/etc/xbps.d"

cp /etc/hostid "${CHROOT_MNT}/etc/"
cp /etc/resolv.conf "${CHROOT_MNT}/etc/"
cp /etc/rc.conf "${CHROOT_MNT}/etc/"

echo "repository=${REPO}" > "${CHROOT_MNT}/etc/xbps.d/00-repository-main.conf"

# Add ZFSBootMenu population script
if [ -x ./helpers/zbm-populate.sh ]; then
  mkdir -p "${CHROOT_MNT}/root"
  cp ./helpers/zbm-populate.sh "${CHROOT_MNT}/root/"
fi
