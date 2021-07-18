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
  if ! bldctx="$( realpath -e contrib/docker )"; then
    error "missing contrib/docker, cannot create image ${buildtag}"
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

buildtmp="$( mktemp -d )"

mkdir -p "${buildtmp}/dracut.conf.d"

# Copy default dracut configuration and include a release-specific config
if ! cp etc/zfsbootmenu/dracut.conf.d/* "${buildtmp}/dracut.conf.d"; then
  error "failed to copy dracut configuration"
fi

cat <<-EOF > "${buildtmp}/dracut.conf.d/release.conf"
	zfsbootmenu_teardown+="/zbm/contrib/xhci-teardown.sh"
        install_optional_items+=" /etc/zbm-commit-hash "
	omit_drivers+=" amdgpu radeon nvidia nouveau i915 "
	omit_dracutmodules+=" network network-legacy kernel-network-modules "
	omit_dracutmodules+=" qemu qemu-net crypt-ssh nfs lunmask "
	embedded_kcl="rd.hostonly=0"
	release_build=1
EOF

yamlconf="${buildtmp}/config.yaml"

if ! cp etc/zfsbootmenu/config.yaml "${yamlconf}"; then
  error "failed to copy default ZFSBootMenu configuration"
fi

arch="$( uname -m )"
BUILD_EFI="false"

case "${arch}" in
  x86_64) BUILD_EFI="true" ;;
  *) ;;
esac

zbmtriplet="zfsbootmenu-${arch}-v${release}"

# Modify the YAML configuration for the containerized build
yq-go eval ".Components.Enabled = true" -i "${yamlconf}"
yq-go eval ".Components.Versions = false" -i "${yamlconf}"
yq-go eval ".Components.ImageDir = \"/build/${zbmtriplet}\"" -i "${yamlconf}"
yq-go eval ".EFI.Enabled = ${BUILD_EFI}" -i "${yamlconf}"
yq-go eval ".EFI.Versions = false" -i "${yamlconf}"
yq-go eval ".EFI.ImageDir = \"/build/uefi\"" -i "${yamlconf}"
yq-go eval ".Global.ManageImages = true" -i "${yamlconf}"
yq-go eval ".Global.DracutConfDir = \"/build/dracut.conf.d\"" -i "${yamlconf}"
yq-go eval ".Global.DracutFlags = [ \"--no-early-microcode\" ]" -i "${yamlconf}"
yq-go eval ".Kernel.CommandLine = \"loglevel=4 nomodeset\"" -i "${yamlconf}"
yq-go eval "del(.Global.BootMountPoint)" -i "${yamlconf}"

# For the containerized build, use current repo by mounting at /zbm
# Custom configs and outputs will be in the temp dir, mounted at /build
podman run --rm -v ".:/zbm:ro" -v "${buildtmp}:/build" "${buildtag}" "/build" || exit 1

if ! assets="$( realpath -e releng )/assets/${release}"; then
  error "unable to define path to built assets"
fi

if [ -d "${assets}" ]; then
  rm -f "${assets}"/*
else
  mkdir -p "${assets}"
fi

# EFI file is currently only built on x86_64
if [ "${BUILD_EFI}" = "true" ]; then
  cp "${buildtmp}/uefi/vmlinuz.EFI" "${assets}/${zbmtriplet}.EFI" || exit 1
fi

# Components are always built
( cd "${buildtmp}" && tar czvf "${assets}/${zbmtriplet}.tar.gz" "${zbmtriplet}" ) || exit 1
