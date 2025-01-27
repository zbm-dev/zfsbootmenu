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

buildtag="${2:-ghcr.io/zbm-dev/zbm-builder:$(date '+%Y%m%d')}"
if ! podman inspect "${buildtag}" >/dev/null 2>&1; then
  build_args=( "${buildtag}" "${ZBM_COMMIT_HASH:-"v${release}"}" )

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

# Common volume mounts for the container:
# - Current repo is the tree from which builds will be made
# - A read-only "build" directory (to be made) will contain configuration
volmounts=(
  "-v" ".:/zbm:ro"
  "-v" "${buildtmp}/build:/build:ro"
)

if ! assets="$( realpath -e releng )/assets/${release}"; then
  error "unable to define path to built assets"
fi

if [ -d "${assets}" ]; then
  rm -f "${assets}"/*
else
  mkdir -p "${assets}"
fi

kernels="$(podman run --rm --entrypoint /bin/sh "${buildtag}" -c \
  "xbps-query -p pkgver -s '^linux[0-9]+\.[0-9]+' --regex \
    | sed 's/: .*//' | xargs -n1 xbps-uhelper getpkgversion | sort | uniq")" || kernels=

for style in release recovery; do
  echo "Building style: ${style}"

  # Always start with a fresh configuration tree
  mkdir -p "${buildtmp}/build/dracut.conf.d" || error "cannot create config tree"

  # Copy style-specific configuration components in place;
  # build container sets up standard configuration elements
  cp "./etc/zfsbootmenu/${style}.yaml" "${buildtmp}/build/config.yaml"
  cp "./etc/zfsbootmenu/${style}.conf.d/"*.conf "${buildtmp}/build/dracut.conf.d"

  # Make sure there is an output directory for this asset style
  zbmtriplet="zfsbootmenu-${style}-${arch}-v${release}"

  for kern in ${kernels}; do
    kern_args=()
    if [ -n "${kern}" ]; then
      echo "Building style ${style} for kernel ${kern}"
      kern_args=( "--" "--kver" "${kern}" )
    fi

    outdir="${buildtmp}/${zbmtriplet}"
    mkdir -p "${outdir}" || error "cannot create output directory"

    # In addition to common mounts which expose source repo and build configs,
    # make sure a writable output directory is available for this style and
    # build the EFI bundle if it is supported for this arch
    if ! podman run --rm \
        "${volmounts[@]}" -v "${outdir}:/out" \
        "${buildtag}" -o /out -e ".EFI.Enabled = ${BUILD_EFI}" "${kern_args[@]}"; then
      error "failed to create image"
    fi

    if [ "${BUILD_EFI}" = "true" ]; then
      # If EFI file was produced, copy it
      efibase="${zbmtriplet}-vmlinuz"
      [ -n "${kern}" ] && efibase="${efibase}-${kern}"
      if ! cp "${outdir}/vmlinuz.EFI" "${assets}/${efibase}.EFI"; then
        error "failed to copy UEFI bundle"
      fi
      rm -f "${outdir}/vmlinuz.EFI"
    fi

    have_components=
    for f in "${outdir}"/*; do
      [ -e "${f}" ] || continue
      have_components="yes"
      break
    done

    if [ -n "${have_components}" ]; then
      # If components were produced, archive them
      tarbase="${zbmtriplet}"
      [ -n "${kern}" ] && tarbase="${tarbase}-${kern}"
      ( cd "${buildtmp}" && \
        tar -czvf "${assets}/${tarbase}.tar.gz" "${zbmtriplet}"
      ) || error "failed to pack components"
    fi

    rm -rf "${outdir}"
  done

  # Clean up the style-specific build components
  rm -rf "${buildtmp}/build"
done
