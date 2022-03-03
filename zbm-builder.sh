#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

usage() {
  cat <<EOF
Usage: $0 [options]
  OPTIONS:
  -h Display help text

  -H Do not copy /etc/hostid into image
     (Has no effect if ./hostid exists)

  -C Do not copy /etc/zfs/zpool.cache into image
     (Has no effect if ./zpool.cache exists)

  -d Force use of docker instead of podman

  -t <tag>
     Build the given ZFSBootMenu tag
     (Default: upstream master)

  -B <tag>
     Use the given zbm-builder tag to build images
     (Default: ghcr.io/zbm-dev/zbm-builder:latest)
EOF
}

if command -v podman >/dev/null 2>&1; then
  PODMAN=podman
elif command -v docker >/dev/null 2>&1; then
  PODMAN=docker
fi

SKIP_HOSTID=
SKIP_CACHE=

BUILD_TAG="ghcr.io/zbm-dev/zbm-builder:latest"

BUILD_ARGS=()

while getopts "hHCdt:B:" opt; do
  case "${opt}" in
    H)
      SKIP_HOSTID="yes"
      ;;
    C)
      SKIP_CACHE="yes"
      ;;
    d)
      PODMAN=docker
      ;;
    t)
      BUILD_ARGS+=( "-t" "${OPTARG}" )
      ;;
    B)
      BUILD_TAG="${OPTARG}"
      ;;
    h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

if ! command -v "${PODMAN}" >/dev/null 2>&1; then
  echo "ERROR: container front-end ${PODMAN} not found"
  exit 1
fi

# If no local hostid is available, copy the system hostid if desired
if ! [ -r ./hostid ]; then
  if [ "${SKIP_HOSTID}" != "yes" ] && [ -r /etc/hostid ]; then
    if ! cp /etc/hostid ./hostid; then
      echo "ERROR: unable to copy /etc/hostid"
      echo "Copy a hostid file to ./hostid or use -H to disable"
      exit 1
    fi
  fi
fi

# If no local zpool.cache is available, copy the system cache if desired
if ! [ -r ./zpool.cache ]; then
  if [ "${SKIP_CACHE}" != "yes" ] && [ -r /etc/zfs/zpool.cache ]; then
    if ! cp /etc/zfs/zpool.cache ./zpool.cache; then
      echo "ERROR: unable to copy /etc/zfs/zpool.cache"
      echo "Copy a zpool cache to ./zpool.cache or use -C to disable"
      exit 1
    fi
  fi
fi

# If no config is specified, use in-tree default
if ! [ -r ./config.yaml ]; then
  BUILD_ARGS+=( "-c" "/zbm/etc/zfsbootmenu/config.yaml" )
fi

# Make `/build` the working directory so relative paths in a config file make sense
"${PODMAN}" run --rm -v "$(pwd):/build" -w "/build" "${BUILD_TAG}" "${BUILD_ARGS[@]}"
