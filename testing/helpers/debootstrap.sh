#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# Just use a built-in debootstrap if possible
if command -v debootstrap >/dev/null 2>&1; then
  exec debootstrap "$@"
fi

cleanup() {
  if [ -n "${DEBROOT}" ]; then
    rm -rf "${DEBROOT}"
    unset DEBROOT
  fi

  exit
}

trap cleanup EXIT INT TERM

if ! DEBROOT="$( mktemp -d )"; then
  echo "ERROR: unable to create working directory for debootstrap"
  exit 1
fi

export DEBROOT

(cd "${DEBROOT}" && \
  git clone --depth=1 https://salsa.debian.org/installer-team/debootstrap.git)

if [ ! -x "${DEBROOT}/debootstrap/debootstrap" ]; then
  echo "ERROR: unable to find local clone of debootstrap"
  exit 1
fi

export DEBOOTSTRAP_DIR="${DEBROOT}/debootstrap"

DEBARCH=
case "$(uname -m)" in
  x86_64) DEBARCH=amd64 ;;
  i686) DEBARCH=i386 ;;
  aarch64) DEBARCH=arm64 ;;
  armv7l) DEBARCH=armhf ;;
  *) ;;
esac

if [ -z "${DEBARCH}" ]; then
  echo "ERROR: unable to find supported architecture"
  exit 1
fi

echo "${DEBARCH}" > "${DEBOOTSTRAP_DIR}/arch"
"${DEBOOTSTRAP_DIR}/debootstrap" "$@"
