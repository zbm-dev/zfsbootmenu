#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

check() {
  # Do not include this module by default; it must be requested
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

  for mod in "${required_modules[@]}"; do
    if ! instmods -c "${mod}" ; then
      dfatal "Required kernel module '${mod}' is missing, aborting image creation!"
      exit 1
    fi
  done

  local optional_modules=(
    "zlib_deflate"
    "zlib_inflate"
  )

  for mod in "${optional_modules[@]}"; do
    instmods "${mod}"
  done
}

install() {
  local _rule _exec _ret

  local udev_rules=(
    "/usr/lib/udev/rules.d/90-zfs.rules"
    "/usr/lib/udev/rules.d/69-vdev.rules"
    "/usr/lib/udev/rules.d/60-zvol.rules"
  )

  for _rule in "${udev_rules[@]}"; do
    if ! inst_rules "${_rule}"; then
      dfatal "failed to install udev rule '${_rule}'"
      exit 1
    fi
  done

  local essential_execs=(
    "/usr/lib/udev/vdev_id"
    "/usr/lib/udev/zvol_id"
    "zfs"
    "zpool"
    "hostid"
    "mount"
    "mount.zfs"
    "kexec"
    "mkdir"
    "tput"
    "basename"
    "head"
    "mktemp"
    "sort"
    "sed"
    "grep"
    "tail"
    "tr"
    "tac"
    "blkid"
  )

  for _exec in "${essential_execs[@]}"; do
    if ! dracut_install "${_exec}"; then
      dfatal "failed to install essential executable '${_exec}'"
      exit 1
    fi
  done

  # sk can be used as a substitute for fzf
  if ! dracut_install fzf && ! dracut_install sk; then
    dfatal "failed to install fzf or sk"
    exit 1
  fi

  # BE clones will work (silently and less efficiently) without mbuffer
  if ! dracut_install mbuffer; then
    dwarning "mbuffer not found; ZFSBootMenu cannot show progress during BE clones"
  fi

  # Workaround for zfsonlinux/zfs#4749 by ensuring libgcc_s.so(.1) is included
  _ret=0
  if ldd /usr/bin/zpool | grep -qF 'libgcc_s.so'; then
    # Dracut will have already tracked and included it
    :
  elif command -v gcc-config >/dev/null 2>&1; then
    # On systems with gcc-config (Gentoo, Funtoo, etc.):
    # Use the current profile to resolve the appropriate path
    dracut_install "/usr/lib/gcc/$(s=$(gcc-config -c); echo "${s%-*}/${s##*-}")/libgcc_s.so.1"
    _ret=$?
  elif [[ -n "$(ls /usr/lib/libgcc_s.so* 2>/dev/null)" ]]; then
    # Try a simple path first
    dracut_install /usr/lib/libgcc_s.so*
    _ret=$?
  else
    # Fallback: Guess the path and include all matches
    dracut_install /usr/lib/gcc/*/*/libgcc_s.so*
    _ret=$?
  fi

  if [ ${_ret} -ne 0 ]; then
    dfatal "Unable to install libgcc_s.so"
    exit 1
  fi

  _ret=0
  # shellcheck disable=SC2154
  inst_simple "${moddir}/zfsbootmenu-lib.sh" "/lib/zfsbootmenu-lib.sh" || _ret=$?
  inst_simple "${moddir}/zfsbootmenu-preview.sh" "/bin/zfsbootmenu-preview.sh" || _ret=$?
  inst_simple "${moddir}/zfs-chroot" "/bin/zfs-chroot" || _ret=$?
  inst_hook cmdline 95 "${moddir}/zfsbootmenu-parse-commandline.sh" || _ret=$?
  inst_hook pre-mount 90 "${moddir}/zfsbootmenu.sh" || _ret=$?

  if [ ${_ret} -ne 0 ]; then
    dfatal "Unable to install core ZFSBootMenu functions"
    exit 1
  fi

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
