#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

cleanup () {
  if [ -n "${APKROOT}" ]; then
    rm -rf "${APKROOT}"
    unset APKROOT
  fi

  exit
}

if [ -z "${CHROOT_MNT}" ] || [ ! -d "${CHROOT_MNT}" ]; then
  echo "ERROR: chroot mountpoint must be specified and must exist"
  exit 1
fi

if ! APKROOT="$( mktemp -d )"; then
  echo "ERROR: cannot make directory to unpack apk"
  exit 1
else
  export APKROOT
fi

trap cleanup EXIT INT TERM

MIRROR="http://dl-cdn.alpinelinux.org/alpine/latest-stable/main"
PATTERN="apk-tools-static-[.0-9]\+-r[0-9]\+.apk"
if ! ./helpers/extract_remote.sh "${MIRROR}/x86_64/" "${APKROOT}" "${PATTERN}"; then
  echo "ERROR: could not fetch and extract static apk tools"
  exit 1
fi

"${APKROOT}/sbin/apk.static" --arch "x86_64" -X "${MIRROR}" \
  -U --allow-untrusted --root "${CHROOT_MNT}" --initdb add alpine-base

mkdir -p "${CHROOT_MNT}/etc"
cp /etc/hostid "${CHROOT_MNT}/etc/"
cp /etc/resolv.conf "${CHROOT_MNT}/etc/"

# Alpine does not even provide dracut, why bother populating a ZBM repo?
