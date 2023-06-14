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

  case "${val,,}" in
    yes|y|on|1) return 0 ;;
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

  -c <config>
     Specify the path to a configuration file that will be sourced
     (Default: \${BUILD_DIRECTORY}/zbm-builder.conf, if it exists)

  -d Force use of docker instead of podman

  -M <argument>
     Provide a comma-separated list of options to use for volume
     mounts of the build directory and (if specified) ZFSBootMenu
     source tree within the build container. For example, specify

       zbm-builder -M z

     to label the volumes for use with SELinux.

     NOTE: An 'ro' option is always added to the volume mounted from
     the ZFSBootMenu source tree.

  -O <argument>
     Provide an option to 'podman run' or 'docker run'; if the
     argument accepts one or more options, use a form with no spaces
     or make sure each option gets its own '-O', e.g.:

       zbm-builder -O -v -O /boot/efi/EFI/zfsbootmenu:/output
       zbm-builder -O --volume -O /boot/efi/EFI/zfsbootmenu:/output
       zbm-builder -O --volume=/boot/efi/EFI/zfsbootmenu:/output

     May be specified multiple times.

  -i <image>
     Build within the named container image
     (Default: ghcr.io/zbm-dev/zbm-builder:latest)

  -l <path>
     Build from ZFSBootMenu source tree at <path>
     (Default: fetch upstream source tree inside container)

  -R Remove any existing hostid in the build directory

  -H Do not include host /etc/hostid in image
     (If ./hostid exists, this switch will be ignored)

  -- <arguments>
     Additional arguments to the zbm-builder container

For more information, see documentation at

  https://github.com/zbm-dev/zfsbootmenu/blob/master/README.md
  https://github.com/zbm-dev/zfsbootmenu/blob/master/docs/BUILD.md
EOF
}

SKIP_HOSTID=
REMOVE_HOST_FILES=
MOUNT_FLAGS=

# By default, use the latest upstream build container image
BUILD_IMG="ghcr.io/zbm-dev/zbm-builder:latest"

# By default, build from the current directory
BUILD_DIRECTORY="${PWD}"

# By default, there is no local repo
BUILD_REPO=

# Arguments to the build script
BUILD_ARGS=()

# Arguments for the container runtime
RUNTIME_ARGS=()

# Optional configuration file
CONFIG=

if command -v podman >/dev/null 2>&1; then
  PODMAN="podman"
else
  PODMAN="docker"
fi

CMDOPTS="b:dhi:l:c:M:O:HR"

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
    M)
      MOUNT_FLAGS="${OPTARG}"
      ;;
    O)
      RUNTIME_ARGS+=( "${OPTARG}" )
      ;;
    H)
      SKIP_HOSTID="yes"
      ;;
    R)
      REMOVE_HOST_FILES="yes"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

# Drop all processed arguments
shift $((OPTIND-1))

if ! command -v "${PODMAN}" >/dev/null 2>&1; then
  echo "ERROR: this script requires podman or docker"
  exit 1
fi

# Always mount a build directory at /build
RUNTIME_ARGS+=( "-v" "${BUILD_DIRECTORY}:/build${MOUNT_FLAGS:+:${MOUNT_FLAGS}}" )

# Only mount a local repo at /zbm if specified
if [ -n "${BUILD_REPO}" ]; then
  if ! BUILD_REPO="$( sanitise_path "${BUILD_REPO}" )"; then
    echo "ERROR: local repository does not exist"
    exit 1
  fi

  RUNTIME_ARGS+=( "-v" "${BUILD_REPO}:/zbm:ro${MOUNT_FLAGS:+,${MOUNT_FLAGS}}" )
fi

# Remove existing hostid
if boolean_enabled "${REMOVE_HOST_FILES}" && [ -e "${BUILD_DIRECTORY}/hostid" ]; then
  if ! rm "${BUILD_DIRECTORY}/hostid"; then
    echo "ERROR: failed to remove hostid from build directory"
    exit 1
  fi
  echo "Removed hostid by user request"
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

# If no config is specified, use in-tree default but force EFI and components
if ! [ -r "${BUILD_DIRECTORY}"/config.yaml ]; then
  BUILD_ARGS=(
    "-e" ".EFI.Enabled=true"
    "-e" ".Components.Enabled=true"
    "${BUILD_ARGS[@]}"
  )
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
exec "${PODMAN}" run \
  --rm -w "/build" "${RUNTIME_ARGS[@]}" \
  "${BUILD_IMG}" "${BUILD_ARGS[@]}" "$@"
