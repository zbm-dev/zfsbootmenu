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
  build_args=( "${buildtag}" )

  if [ -n "${ZBM_COMMIT_HASH}" ]; then
    build_args+=( "${ZBM_COMMIT_HASH}" )
  fi

  if ! ./releng/docker/image-build.sh "${build_args[@]}"; then
    error "failed to create builder image"
  fi
fi

arch="$( uname -m )"
case "${arch}" in
  x86_64) BUILD_EFI="true" ;;
  *) BUILD_EFI="false" ;;
esac

buildtmp="$( mktemp -d )" || error "cannot create build directory"
mkdir -p "${buildtmp}/out" || error "cannot create output directory"

# Volume mounts for the container:
# - Current repo is the tree from which builds will be made
# - A read-only "build" directory (to be made) will contain configuration
# - Output directory will receive build products
volmounts=(
  "-v" ".:/zbm:ro"
  "-v" "${buildtmp}/build:/build:ro"
  "-v" "${buildtmp}/out:/out"
)

if ! assets="$( realpath -e releng )/assets/${release}"; then
  error "unable to define path to built assets"
fi

if [ -d "${assets}" ]; then
  rm -f "${assets}"/*
else
  mkdir -p "${assets}"
fi

for style in release recovery; do
  echo "Building style: ${style}"

  # Always start with a fresh configuration tree
  mkdir -p "${buildtmp}/build/dracut.conf.d" || error "cannot create config tree"

  # Copy style-specific configuration components in place;
  # zbm-build.sh sets up standard configuration elements
  cp "./etc/zfsbootmenu/${style}.yaml" "${buildtmp}/build/config.yaml"
  cp "./etc/zfsbootmenu/${style}.conf.d/"*.conf "${buildtmp}/build/dracut.conf.d"

  # Specify options for the build st
  buildopts=(
    "-o" "/out"
    "-e" ".EFI.Enabled = ${BUILD_EFI}"
  )

  # For the containerized build, use current repo by mounting at /zbm
  # Custom configs and outputs will be in the temp dir, mounted at /build
  if ! podman run --rm "${volmounts[@]}" "${buildtag}" "${buildopts[@]}"; then
    error "failed to create image"
  fi

  zbmtriplet="zfsbootmenu-${style}-vmlinuz-${arch}-v${release}"

  # EFI file is currently only built on x86_64
  if [ "${BUILD_EFI}" = "true" ]; then
    if !  cp "${buildtmp}/out/vmlinuz.EFI" "${assets}/${zbmtriplet}.EFI"; then
      error "failed to copy UEFI bundle"
    fi
  fi

  # Nothing to archive if no components were produced
  [ -d "${buildtmp}/out/components" ] || exit 0

  zbmtriplet="zfsbootmenu-${style}-${arch}-v${release}"
  # If components were produced, archive them
  ( cd "${buildtmp}/out" && mv components "${zbmtriplet}" && \
    tar czvf "${assets}/${zbmtriplet}.tar.gz" "${zbmtriplet}"
  ) || error "failed to pack components"

  # Clean up the style-specific build components
  rm -rf "${buildtmp}/build"
done
