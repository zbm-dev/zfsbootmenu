#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

check() {
  # We depend on udev-rules being loaded
  [ "${1}" = "-d" ] && return 0

  # Verify the zfs tool chain
  for tool in "/usr/bin/zpool" "/usr/bin/zfs" "/usr/bin/mount.zfs" ; do
    test -x "$tool" || return 1
  done
  # Verify grep exists
  command -v grep >/dev/null 2>&1 || return 1

  return 255
}

depends() {
  echo udev-rules
  return 0
}

installkernel() {
  local mod

  local required_modules=(
    "zfs"
    "zcommon"
    "znvpair"
    "zavl"
    "zunicode"
    "zlua"
    "icp"
    "spl"
  )

  for mod in "${required_modules[@]}"
  do
    if ! instmods -c "${mod}" ; then
      dfatal "Required kernel module '${mod}' is missing, aborting image creation!"
      exit 1
    fi
  done

  local optional_modules=(
    "zlib_deflate"
    "zlib_inflate"
  )

  for mod in "${optional_modules[@]}"
  do
    instmods "${mod}"
  done
}

install() {
  inst_rules /usr/lib/udev/rules.d/90-zfs.rules
  inst_rules /usr/lib/udev/rules.d/69-vdev.rules
  inst_rules /usr/lib/udev/rules.d/60-zvol.rules
  dracut_install hostid
  dracut_install /usr/bin/zfs
  dracut_install /usr/bin/zpool
  # Workaround for zfsonlinux/zfs#4749 by ensuring libgcc_s.so(.1) is included
  if ldd /usr/bin/zpool | grep -qF 'libgcc_s.so'; then
    # Dracut will have already tracked and included it
    :;
  elif command -v gcc-config >/dev/null 2>&1; then
    # On systems with gcc-config (Gentoo, Funtoo, etc.):
    # Use the current profile to resolve the appropriate path
    dracut_install "/usr/lib/gcc/$(s=$(gcc-config -c); echo "${s%-*}/${s##*-}")/libgcc_s.so.1"
  elif [[ -n "$(ls /usr/lib/libgcc_s.so* 2>/dev/null)" ]]; then
    # Try a simple path first
    dracut_install /usr/lib/libgcc_s.so*
  else
    # Fallback: Guess the path and include all matches
    dracut_install /usr/lib/gcc/*/*/libgcc_s.so*
  fi
  dracut_install /usr/bin/mount.zfs
  dracut_install /usr/lib/udev/vdev_id
  dracut_install /usr/lib/udev/zvol_id
  dracut_install tac
  dracut_install basename
  dracut_install head
  dracut_install kexec
  dracut_install fzf
  dracut_install mktemp
  dracut_install sort
  dracut_install sed
  dracut_install grep
  dracut_install tput
  dracut_install mount
  dracut_install mkdir
  dracut_install tail
  dracut_install mbuffer
  dracut_install tr

  # shellcheck disable=SC2154
  inst_simple "${moddir}/zfsbootmenu-lib.sh" "/lib/zfsbootmenu-lib.sh"
  inst_simple "${moddir}/zfsbootmenu-preview.sh" "/bin/zfsbootmenu-preview.sh"
  inst_simple "${moddir}/zfs-chroot" "/bin/zfs-chroot"
  inst_hook cmdline 95 "${moddir}/zfsbootmenu-parse-commandline.sh"
  inst_hook pre-mount 90 "${moddir}/zfsbootmenu.sh"

  if [ -e /etc/zfs/zpool.cache ]; then
    inst /etc/zfs/zpool.cache
    type mark_hostonly >/dev/null 2>&1 && mark_hostonly /etc/zfs/zpool.cache
  fi

  if [ -e /etc/zfs/vdev_id.conf ]; then
    inst /etc/zfs/vdev_id.conf
    type mark_hostonly >/dev/null 2>&1 && mark_hostonly /etc/zfs/vdev_id.conf
  fi

  # Synchronize initramfs and system hostid
  HOSTID="$( hostid )"
  # shellcheck disable=SC2154
  echo -ne "\\x${HOSTID:6:2}\\x${HOSTID:4:2}\\x${HOSTID:2:2}\\x${HOSTID:0:2}" > "${initdir}/etc/hostid"
}
