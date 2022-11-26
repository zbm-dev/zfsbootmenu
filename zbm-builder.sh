#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

sanitise_path() {
  local rpath
  if rpath="$(readlink -f "${1}")" && [ -d "${rpath}" ]; then
    echo "${rpath}"
    return 0
  fi

  return 1
}

boolean_enabled() {
  local val="${1:-}"

  case "${val}" in
    [Yy][Ee][Ss]|[Yy]|[Oo][Nn]|1) return 0 ;;
    *) return 1 ;;
  esac
}

usage() {
  cat << EOF
Build ZFSBootMenu images in an OCI container using podman or docker.

Usage: $0 [options]

OPTIONS:

  -h Display this help text

  -b <path>
     Use an alternate build directory
     (Default: current directory)

  -d Force use of docker instead of podman

  -i <image>
     Build within the named container image
     (Default: ghcr.io/zbm-dev/zbm-builder:latest)

  -l <path>
     Build from ZFSBootMenu source tree at <path>
     (Default: fetch upstream source tree inside container)

  -t <tag>
     Build specific ZFSBootMenu commit or tag (e.g. v1.12.0, d5594589)
     (Default: current upstream master)

  -R Remove any existing zpool.cache and hostid in the build directory

  -C Do not include host /etc/zfs/zpool.cache in image
     (If ./zpool.cache exists, this switch will be ignored)

  -H Do not include host /etc/hostid in image
     (If ./hostid exists, this switch will be ignored)

  -p <pkg>
     Include the named Void Linux package in the build container
     (May be specified multiple times to add multiple packages)

  -v <src-path>:<container-path>[:opts]
     Bind-mount the source path <src-path> at <container-path>
     inside the container, using Docker-stype volume syntax
     (May be specified multiple times for multiple mounts)

For more information, see documentation at

  https://github.com/zbm-dev/zfsbootmenu/blob/master/README.md
  https://github.com/zbm-dev/zfsbootmenu/blob/master/docs/BUILD.md
EOF
}

SKIP_HOSTID=
SKIP_CACHE=
REMOVE_HOST_FILES=

# By default, use the latest upstream build container image
BUILD_IMG="ghcr.io/zbm-dev/zbm-builder:latest"

# By default, build from the current directory
BUILD_DIRECTORY="${PWD}"

# By default, there is no local repo or repo tag
BUILD_REPO=
BUILD_TAG=

# Arguments to the build script
BUILD_ARGS=()

# Volume mounts for the container manager
VOLUME_ARGS=()

# Optional configuration file
CONFIG=

if command -v podman >/dev/null 2>&1; then
  PODMAN="podman"
else
  PODMAN="docker"
fi

CMDOPTS="b:dhi:l:t:p:v:c:CHR"

# First pass to get build directory and configuration file
while getopts "${CMDOPTS}" opt; do
  case "${opt}" in
    b)
      BUILD_DIRECTORY="${OPTARG}"
      ;;
    c)
      CONFIG="${OPTARG}"
      ;;
    h)
      usage
      exit 0
      ;;
  esac
done

# Make sure the build directory is identifiable
if ! BUILD_DIRECTORY="$( sanitise_path "${BUILD_DIRECTORY}" )"; then
  echo "ERROR: build directory does not exist"
  exit 1
fi

# If a configuration wasn't specified, use a default it one exists
if [ -z "${CONFIG}" ] && [ -r "${BUILD_DIRECTORY}/zbm-builder.conf" ]; then
  CONFIG="${BUILD_DIRECTORY}/zbm-builder.conf"
fi

# Read the optional configuration
if [ -n "${CONFIG}" ]; then
  if [ -r "${CONFIG}" ]; then
    # shellcheck disable=SC1090
    source "${CONFIG}"
  else
    echo "ERROR: non-existent configuration specified"
    exit 1
  fi
fi

OPTIND=1
while getopts "${CMDOPTS}" opt; do
  case "${opt}" in
    # These have already been parsed in first pass
    b|c|h)
      ;;
    d)
      PODMAN=docker
      ;;
    i)
      BUILD_IMG="${OPTARG}"
      ;;
    l)
      BUILD_REPO="${OPTARG}"
      ;;
    t)
      BUILD_TAG="${OPTARG}"
      ;;
    C)
      SKIP_CACHE="yes"
      ;;
    H)
      SKIP_HOSTID="yes"
      ;;
    R)
      REMOVE_HOST_FILES="yes"
      ;;
    p)
      BUILD_ARGS+=( "-p" "${OPTARG}" )
      ;;
    v)
      VOLUME_ARGS+=( "-v" "${OPTARG}" )
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

if ! command -v "${PODMAN}" >/dev/null 2>&1; then
  echo "ERROR: this script requires podman or docker"
  exit 1
fi

# Always mount a build directory at /build
VOLUME_ARGS+=( "-v" "${BUILD_DIRECTORY}:/build" )

# Only mount a local repo at /zbm if specified
if [ -n "${BUILD_REPO}" ]; then
  if ! BUILD_REPO="$( sanitise_path "${BUILD_REPO}" )"; then
    echo "ERROR: local repository does not exist"
    exit 1
  fi

  VOLUME_ARGS+=( "-v" "${BUILD_REPO}:/zbm:ro" )
fi

# If a tag was specified for building, pass to the container
if [ -n "${BUILD_TAG}" ]; then
  BUILD_ARGS+=( "-t" "${BUILD_TAG}" )
fi

if boolean_enabled "${REMOVE_HOST_FILES}"; then
  # Remove existing host files
  for host_file in "hostid" "zpool.cache"; do
    [ -e "${BUILD_DIRECTORY}/${host_file}" ] || continue
    if ! rm "${BUILD_DIRECTORY}/${host_file}"; then
      echo "ERROR: failed to remove file '${host_file}' from build directory"
      exit 1
    fi
    echo "Removed file '${host_file}' by user request"
  done
fi

# If no local hostid is available, copy the system hostid if desired
if ! [ -r "${BUILD_DIRECTORY}"/hostid ]; then
  if ! boolean_enabled "${SKIP_HOSTID}" && [ -r /etc/hostid ]; then
    if ! cp /etc/hostid "${BUILD_DIRECTORY}"/hostid; then
      echo "ERROR: unable to copy /etc/hostid"
      echo "Copy a hostid file to ./hostid or use -H to disable"
      exit 1
    fi
  fi
fi

# If no local zpool.cache is available, copy the system cache if desired
if ! [ -r "${BUILD_DIRECTORY}"/zpool.cache ]; then
  if ! boolean_enabled "${SKIP_CACHE}" && [ -r /etc/zfs/zpool.cache ]; then
    if ! cp /etc/zfs/zpool.cache "${BUILD_DIRECTORY}"/zpool.cache; then
      echo "ERROR: unable to copy /etc/zfs/zpool.cache"
      echo "Copy a zpool cache to ./zpool.cache or use -C to disable"
      exit 1
    fi
  fi
fi

# If no config is specified, use in-tree default but force EFI and components
if ! [ -r "${BUILD_DIRECTORY}"/config.yaml ]; then
  BUILD_ARGS+=( "-e" ".EFI.Enabled=true" )
  BUILD_ARGS+=( "-e" ".Components.Enabled=true" )
fi

# Try to include ZBM hooks in the images by default
for stage in early_setup setup teardown; do
  [ -d "${BUILD_DIRECTORY}/hooks.${stage}.d" ] || continue

  # Only executable hooks are added to the image
  hooks=()
  for f in "${BUILD_DIRECTORY}/hooks.${stage}.d"/*; do
    [ -x "${f}" ] || continue
    hooks+=( "/build/hooks.${stage}.d/${f##*/}" )
  done

  [ "${#hooks[@]}" -gt 0 ] || continue

  hconf="zbm-builder.${stage}.conf"

  # Write a dracut configuration snippet
  mkdir -p "${BUILD_DIRECTORY}/dracut.conf.d"
  echo "zfsbootmenu_${stage}+=\" ${hooks[*]} \"" > "${BUILD_DIRECTORY}/dracut.conf.d/${hconf}"

  # Write a mkinitcpio configuration snippet
  mkdir -p "${BUILD_DIRECTORY}/mkinitcpio.conf.d"
  echo "zfsbootmenu_${stage}=(" > "${BUILD_DIRECTORY}/mkinitcpio.conf.d/${hconf}"
  for hook in "${hooks[@]}"; do
    echo "  \"${hook}\"" >> "${BUILD_DIRECTORY}/mkinitcpio.conf.d/${hconf}"
  done
  echo ")" >> "${BUILD_DIRECTORY}/mkinitcpio.conf.d/${hconf}"
done

# Make `/build` the working directory so relative paths in configs make sense
exec "${PODMAN}" run --rm "${VOLUME_ARGS[@]}" -w "/build" "${BUILD_IMG}" "${BUILD_ARGS[@]}"
