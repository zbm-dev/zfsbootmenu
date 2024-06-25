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

fixup_debootstrap() {
  # Recent ubstream releases dropped a bunch of Ubuntu symlinks
  # These all seemed to point to the "gutsy" script, so restore them

  local rel releases root

  root="${1}"

  if [ ! -e "${root}/debootstrap" ] || [ ! -e "${root}/scripts/gutsy" ]; then
    echo "ERROR: debootstrap root appears malformed"
    return 1
  fi

  chmod a+x "${root}/debootstrap"

  releases=(
    artful bionic cosmic disco eoan focal groovy
    hirsute impish jammy kinetic lunar mantic noble
  )

  for rel in "${releases[@]}"; do
    ln -Tsf "gutsy" "${root}/scripts/${rel}"
  done

  return 0
}

trap cleanup EXIT INT TERM

if ! DEBROOT="$( mktemp -d )"; then
  echo "ERROR: unable to create working directory for debootstrap"
  exit 1
fi

export DEBROOT

archive="https://salsa.debian.org/installer-team/debootstrap/-/archive/master/debootstrap-master.tar.gz"
( cd "${DEBROOT}" && \
  curl -L "${archive}" | tar zxvf - && \
  mv debootstrap-master debootstrap )

export DEBOOTSTRAP_DIR="${DEBROOT}/debootstrap"

fixup_debootstrap "${DEBOOTSTRAP_DIR}"

if [ ! -x "${DEBOOTSTRAP_DIR}/debootstrap" ]; then
  echo "ERROR: unable to find local clone of debootstrap"
  exit 1
fi


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
