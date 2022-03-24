#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

sanitise_path() {
  if PATH=$(readlink -f "${1}") && [ -d ${PATH} ]; then
    echo "${PATH}"
    return 0
  else
    return 1
  fi
}

usage() {
  cat << EOF

zbm-builder.sh

This script generates bootable ZFSBootMenu components inside a pre-made
build container, freeing the user from having to install ZFSBootMenu and
dependencies on the host system or invoke the build scripts directly.

For more information, please see BUILD.md and README.md, or find the latest
documentation at https://github.com/zbm-dev/zfsbootmenu/

Usage: $0 [options]

  OPTIONS:
 
  -b <path>
     Use an alternate build directory for the container.
     (By default, the directory containing 'zbm-builder.sh' is used.)

  -d Force use of Docker instead of Podman as container management tool.

  -h Display this help text.

  -i <image>
     Use a different container image or version as build environment.
     (By default, the official ghcr.io/zbm-dev/zbm-builder:latest is used.)

  -l <path>
     Use local ZFSBootMenu source tree at <path> instead of remote repository.
     (By default, a source archive is pulled by the container from GitHub.)

  -t <tag>
     Build a specific ZFSBootMenu commit or tag (e.g. v1.12.0, v1.10.1, d5594589).
     (By default, the current upstream master is used.)

  -C Do not integrate /etc/zfs/zpool.cache into build image image from host.
     (If ./zpool.cache exists, this switch will be ignored.)

  -H Do not integrate /etc/hostid into build image from host.
     (If ./hostid exists, this switch will be ignored.)

EOF
}
  
SKIP_HOSTID=
SKIP_CACHE=

BUILD_TAG="ghcr.io/zbm-dev/zbm-builder:latest"
BUILD_DIRECTORY=
LOCAL_SOURCE=

BUILD_ARGS=()
VOLUME_ARGS=()

HOOKS_EARLY_SETUP=()
HOOKS_SETUP=()
HOOKS_TEARDOWN=()

if command -v podman >/dev/null 2>&1; then
  PODMAN="podman"
elif command -v docker >/dev/null 2>&1; then
  PODMAN="docker"
else
  echo "Error: No suitable container management front-end found."
  exit 1
fi

while getopts "b:dhi:l:t:CH" opt; do
  case "${opt}" in
    b)
      BUILD_DIRECTORY="${OPTARG}"
      ;;
    d)
      PODMAN=docker
      ;;
    h)
      usage
      exit 0
      ;;
    i)
      BUILD_TAG="${OPTARG}"
      ;;
    l)
      LOCAL_SOURCE="${OPTARG}"
     ;;
    t)
      BUILD_ARGS+=( "-t" "${OPTARG}" )
      ;;
    C)
      SKIP_CACHE="yes"
      ;;
    H)
      SKIP_HOSTID="yes"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

if [ -z "${BUILD_DIRECTORY}" ]; then
  BUILD_DIRECTORY="${PWD}"
fi

if BUILD_DIRECTORY="$(sanitise_path "${BUILD_DIRECTORY}")"; then
  VOLUME_ARGS+=( "-v" "${BUILD_DIRECTORY}:/build" )
else
  echo "Error: Cannot canonicalise specified build directory path."
  exit 1
fi

if [ -n "${LOCAL_SOURCE}" ]; then
  if LOCAL_SOURCE="$(sanitise_path "${LOCAL_SOURCE}")"; then
    VOLUME_ARGS+=( "-v" "${LOCAL_SOURCE}:/zbm")
  else
   echo "Error: Cannot canonicalise specified source directory path."
   exit 1
  fi
fi

# If no local hostid is available, copy the system hostid if desired
if ! [ -r "${BUILD_DIRECTORY}"/hostid ]; then
  if [ "${SKIP_HOSTID}" != "yes" ] && [ -r /etc/hostid ]; then
    if ! cp /etc/hostid "${BUILD_DIRECTORY}"/hostid; then
      echo "ERROR: unable to copy /etc/hostid"
      echo "Copy a hostid file to ./hostid or use -H to disable"
      exit 1
    fi
  fi
fi

# If no local zpool.cache is available, copy the system cache if desired
if ! [ -r "${BUILD_DIRECTORY}"/zpool.cache ]; then
  if [ "${SKIP_CACHE}" != "yes" ] && [ -r /etc/zfs/zpool.cache ]; then
    if ! cp /etc/zfs/zpool.cache "${BUILD_DIRECTORY}"/zpool.cache; then
      echo "ERROR: unable to copy /etc/zfs/zpool.cache"
      echo "Copy a zpool cache to ./zpool.cache or use -C to disable"
      exit 1
    fi
  fi
fi

# If no config is specified, use in-tree default, do efi and kernel/initramfs
if ! [ -r "${BUILD_DIRECTORY}"/config.yaml ]; then
  BUILD_ARGS+=( "-c" "/zbm/etc/zfsbootmenu/config.yaml" )
  BUILD_ARGS+=( "-e" ".EFI.Enabled=true" )
  BUILD_ARGS+=( "-e" ".Components.Enabled=true" )
fi

# Make `/build` the working directory so relative paths in a config file make sense
"${PODMAN}" run --rm "${VOLUME_ARGS[@]}" -w "/build" "${BUILD_TAG}" "${BUILD_ARGS[@]}"
