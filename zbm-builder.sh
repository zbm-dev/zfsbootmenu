#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

sanitise_path() {
  if [ -d "${OPTARG}" ]; then
    OPTARG=$(readlink -f "${OPTARG}")
  else
    echo "Error: ${OPTARG} is not a valid path."
    exit 1
  fi
}

sanitise_file() {
  if [ -x "${OPTARG}" ] && ! [ -d "${OPTARG}" ]; then
    OPTARG=$(readlink -f "${OPTARG}")
  else
    echo "Error: ${OPTARG} is not a valid, executable file."
    exit 1
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
 
  -1 <file>
     Fetch inidcated file to build directory and mark for integration as
     a 'zfsbootmenu_early_setup' hook. This command can be invoked multiple
     times.

  -2 <file>
     Fetch inidcated file to build directory and mark for integration as
     a 'zfsbootmenu_setup' hook. This comand can be invoked multiple times.
  
  -3 <file>
     Fetch inidcated file to build directory and mark for integration as
     a 'zfsbootmenu_teardown' hook. This command can be invoked multiple
     times.

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
     Build a specific ZFSBootMenu release tag (e.g. v1.12.0, v1.10.1, v1.9.0).
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

while getopts "1:2:3:b:dhi:l:t:CH" opt; do
  case "${opt}" in
    1)
      sanitise_file "${OPTARG}"
      HOOKS_EARLY_SETUP+=( "${OPTARG}" )
    ;;
    2)
      sanitise_file "${OPTARG}"
      HOOKS_SETUP+=( "${OPTARG}" )
    ;;
    3)
      sanitise_file "${OPTARG}"
      HOOKS_TEARDOWN+=( "${OPTARG}" )
    ;;
    b)
      sanitise_path
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
      sanitise_path 
      VOLUME_ARGS+=( "-v" "${OPTARG}:/zbm" )
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

if [ -n "${BUILD_DIRECTORY}" ]; then
  VOLUME_ARGS+=( "-v" "${BUILD_DIRECTORY}:/build" )
else  
  BUILD_DIRECTORY="${PWD}"
  VOLUME_ARGS+=( "-v" "${PWD}:/build" )
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

# custom dracut.conf.d/*.configs need to go into ./build/dracut.conf.d :)
if [ -n "${HOOKS_EARLY_SETUP}" ] || [ -n "${HOOKS_SETUP}" ] || [ -n "${HOOKS_TEARDOWN}" ]; then
  mkdir -p "${BUILD_DIRECTORY}"/dracut.conf.d
fi

if [ -n "${HOOKS_EARLY_SETUP}" ]; then
  # copy requested hook scripts in, then convert canonical path to /build
  for i in "${!HOOKS_EARLY_SETUP[@]}"; do
    cp "${HOOKS_EARLY_SETUP[$i]}" "${BUILD_DIRECTORY}"
    HOOKS_EARLY_SETUP[$i]="/build/`basename ${HOOKS_EARLY_SETUP[$i]}`"
  done
  # echo collated hook scripts to config file
  echo "zfsbootmenu_early_setup+=\" "${HOOKS_EARLY_SETUP[@]}" \"" \
  > "${BUILD_DIRECTORY}"/dracut.conf.d/zfsbootmenu.earlyhooks.conf;
fi

if [ -n "${HOOKS_SETUP}" ]; then
  # copy requested hook scripts in, then convert canonical path to /build
  for i in "${!HOOKS_SETUP[@]}"; do
    cp "${HOOKS_SETUP[$i]}" "${BUILD_DIRECTORY}"
    HOOKS_SETUP[$i]="/build/`basename ${HOOKS_SETUP[$i]}`"
  done
  # echo collated hook scripts to config file
  echo "zfsbootmenu_setup+=\" "${HOOKS_SETUP[@]}" \"" \
  > "${BUILD_DIRECTORY}"/dracut.conf.d/zfsbootmenu.setuphooks.conf;
fi

if [ -n "${HOOKS_TEARDOWN}" ]; then
  # copy requested hook scripts in, then convert canonical path to /build
  for i in "${!HOOKS_TEARDOWN[@]}"; do
    cp "${HOOKS_TEARDOWN[$i]}" "${BUILD_DIRECTORY}"
    HOOKS_TEARDOWN[$i]="/build/`basename ${HOOKS_TEARDOWN[$i]}`"
  done
  # echo collated hook scripts to config file
  echo "zfsbootmenu_teardown+=\" "${HOOKS_TEARDOWN[@]}" \"" \
  > "${BUILD_DIRECTORY}"/dracut.conf.d/zfsbootmenu.teardown.conf;
fi

# Make `/build` the working directory so relative paths in a config file make sense
"${PODMAN}" run --rm "${VOLUME_ARGS[@]}" -w "/build" "${BUILD_TAG}" "${BUILD_ARGS[@]}"
