#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

error() {
  echo "ERROR:" "$@"
  exit 1
}

cleanup() {
  test -d "${buildtmp}" && rm -rf "${buildtmp}"
  unset buildtmp
  exit
}

unset buildtmp
trap cleanup EXIT INT TERM

# Accept release with or without a leading "v"
release="${1#v}"

case "${release}" in
  "") error "usage: $0 <release> [buildtag]" ;;
  */*) error "release must NOT contain a forward slash" ;;
  *) ;;
esac

buildtag="${2:-localhost/zbm-builder:$(date '+%Y%m%d')}"
if ! podman inspect "${buildtag}" >/dev/null 2>&1; then
  if ! bldctx="$( realpath -e releng/docker )"; then
    error "missing releng/docker, cannot create image ${buildtag}"
  fi

  if ZBM_COMMIT_HASH="$(git rev-parse HEAD)" && [ -n "${ZBM_COMMIT_HASH}" ]; then
    build_args=( "--build-arg=ZBM_COMMIT_HASH=${ZBM_COMMIT_HASH}" )
  else
    build_args=()
  fi

  if ! podman build -t "${buildtag}" "${build_args[@]}" "${bldctx}"; then
    error "failed to create builder image"
  fi
fi

buildtmp="$( mktemp -d )" || error "cannot create build directory"
mkdir -p "${buildtmp}/out" || error "cannot create output directory"
mkdir -p "${buildtmp}/etc/dracut.conf.d" || error "cannot create config tree"

# Copy configuration components in place
cp ./etc/zfsbootmenu/release.yaml "${buildtmp}/etc"
cp ./etc/zfsbootmenu/dracut.conf.d/*.conf "${buildtmp}/etc/dracut.conf.d"

# Files in release.conf.d are allowed to shadow regular defaults
cp ./etc/zfsbootmenu/release.conf.d/*.conf "${buildtmp}/etc/dracut.conf.d"

arch="$( uname -m )"
case "${arch}" in
  x86_64) BUILD_EFI="true" ;;
  *) BUILD_EFI="false" ;;
esac

# Volume mounts for the container; make sure stock config tree, with release
# addendum, is available in-container at /etc/zfsbootmenu
volmounts=(
  "-v" ".:/zbm:ro"
  "-v" "${buildtmp}/etc:/etc/zfsbootmenu:ro"
  "-v" "${buildtmp}/out:/out"
)

# Specify options for the build st
buildopts=(
  "-o" "/out"
  "-e" ".EFI.Enabled = ${BUILD_EFI}"
  "-c" "/etc/zfsbootmenu/release.yaml"
)

# For the containerized build, use current repo by mounting at /zbm
# Custom configs and outputs will be in the temp dir, mounted at /build
if ! podman run --rm "${volmounts[@]}" "${buildtag}" "${buildopts[@]}"; then
  error "failed to create image"
fi

if ! assets="$( realpath -e releng )/assets/${release}"; then
  error "unable to define path to built assets"
fi

if [ -d "${assets}" ]; then
  rm -f "${assets}"/*
else
  mkdir -p "${assets}"
fi

zbmtriplet="zfsbootmenu-${arch}-v${release}"

# EFI file is currently only built on x86_64
if [ "${BUILD_EFI}" = "true" ]; then
  if !  cp "${buildtmp}/out/vmlinuz.EFI" "${assets}/${zbmtriplet}.EFI"; then
    error "failed to copy UEFI bundle"
  fi
fi

# Nothing to archive if no components were produced
[ -d "${buildtmp}/out/components" ] || exit 0

# If components were produced, archive them
( cd "${buildtmp}/out" && mv components "${zbmtriplet}" && \
  tar czvf "${assets}/${zbmtriplet}.tar.gz" "${zbmtriplet}"
) || error "failed to pack components"
