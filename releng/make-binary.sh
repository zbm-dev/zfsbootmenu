#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

cleanup() {
  test -d "${temp}" && rm -rf "${temp}"
  exit
}

release="${1?ERROR: no release version specified}"
trap cleanup EXIT INT TERM
temp="$( mktemp -d )"

if [ ! -d /usr/lib/dracut ]; then
  echo "ERROR: missing /usr/lib/dracut"
  exit 1
fi

DRACUTBIN="$( command -v dracut )"
if [ ! -x "${DRACUTBIN}" ]; then
  echo "ERROR: missing dracut script"
  exit 1
fi

assets="$( realpath -e releng)/assets/${release}"
if [ -d "${assets}" ]; then
  rm -f "${assets}"/*
else
  mkdir -p "${assets}"
fi

cp -a /usr/lib/dracut "${temp}"
cp "${DRACUTBIN}" "${temp}/dracut"

cp -Rp etc/zfsbootmenu/dracut.conf.d "${temp}"

cat << EOF > "${temp}/dracut.conf.d/release.conf"
omit_drivers+=" amdgpu radeon nvidia nouveau i915 "
omit_dracutmodules+=" qemu qemu-net crypt-ssh nfs lunmask network network-legacy kernel-network-modules "
embedded_kcl="rd.hostonly=0"
release_build=1
zfsbootmenu_teardown+=" $( realpath contrib/xhci-teardown.sh ) "
EOF

_dracut_mods="${temp}/dracut/modules.d"
test -d "${_dracut_mods}" && rm -rf "${_dracut_mods}/90zfsbootmenu"
ln -s "$(realpath -e 90zfsbootmenu)" "${_dracut_mods}"

ln -s "$(realpath -e bin/generate-zbm)" "${temp}/generate-zbm"

yamlconf="${temp}/local.yaml"
cp etc/zfsbootmenu/config.yaml "${yamlconf}"
build="${temp}/build"

arch="$( uname -m )"
BUILD_EFI="false"

case "${arch}" in
  x86_64)
    BUILD_EFI="true"
    ;;
  *)
    ;;
esac

yq-go eval ".Components.Enabled = true" -i "${yamlconf}"
yq-go eval ".Components.Versions = false" -i "${yamlconf}"
yq-go eval ".Components.ImageDir = \"${build}\"" -i "${yamlconf}"
yq-go eval ".EFI.Enabled = ${BUILD_EFI}" -i "${yamlconf}"
yq-go eval ".EFI.Versions = false" -i "${yamlconf}"
yq-go eval ".EFI.ImageDir = \"${build}\"" -i "${yamlconf}"
yq-go eval ".Global.ManageImages = true" -i "${yamlconf}"
yq-go eval ".Global.DracutConfDir = \"${temp}/dracut.conf.d\"" -i "${yamlconf}"
yq-go eval ".Global.DracutFlags = [ \"--local\", \"--no-early-microcode\" ]" -i "${yamlconf}"
yq-go eval "del(.Global.BootMountPoint)" -i "${yamlconf}"
yq-go eval "del(.Kernel.CommandLine)" -i "${yamlconf}"

"${temp}/generate-zbm" \
  --version "${release}" \
  --config "${yamlconf}" \
  --cmdline "loglevel=4 nomodeset"

# EFI file is currently only built on x86_64
if [ "${BUILD_EFI}" = "true" ]; then
  mv "${build}/vmlinuz.EFI" "${assets}/zfsbootmenu-${arch}-v${release}.EFI"
fi

# Components are always built
components="${build}/zfsbootmenu-${arch}-v${release}"
mkdir -p "${components}"
mv "${build}/initramfs-bootmenu.img" "${components}"
mv "${build}/vmlinuz-bootmenu" "${components}"

( cd "${build}" && tar czvf "${assets}/zfsbootmenu-${arch}-v${release}.tar.gz" "$( basename "${components}" )" ) || exit 1
