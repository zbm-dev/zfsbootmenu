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
    "awk"
    "fold"
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
  inst_simple "${moddir}/zfsbootmenu-countdown.sh" "/libexec/zfsbootmenu-countdown" || _ret=$?
  inst_simple "${moddir}/zfsbootmenu-preview.sh" "/bin/zfsbootmenu-preview.sh" || _ret=$?
  inst_simple "${moddir}/zfs-chroot" "/bin/zfs-chroot" || _ret=$?
  inst_simple "${moddir}/zfsbootmenu.sh" "/bin/zfsbootmenu" || _ret=$?
  inst_simple "${moddir}/zfsbootmenu-input.sh" "/bin/zfsbootmenu-input" || _ret=$?
  inst_simple "${moddir}/zfsbootmenu-help.sh" "/bin/zfsbootmenu-help" || _ret=$?
  inst_hook cmdline 95 "${moddir}/zfsbootmenu-parse-commandline.sh" || _ret=$?
  inst_hook pre-mount 90 "${moddir}/zfsbootmenu-exec.sh" || _ret=$?

  # Install a "teardown" hook if specified and it exists
  # shellcheck disable=SC2154
  if [ -n "${zfsbootmenu_teardown}" ]; then
    if [ -x "${zfsbootmenu_teardown}" ]; then
      inst_simple "${zfsbootmenu_teardown}" "/libexec/zfsbootmenu-teardown" || _ret=$?
    else
      dwarning "no executable teardown script (${zfsbootmenu_teardown}); cannot install"
    fi
  fi

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

  # Try to synchronize hostid between host and ZFSBootMenu
  #
  # DEPRECATION NOTICE: on musl systems, zfs < 2.0 produced a bad hostid in
  # dracut images. Unfortunately, this should be replicated for now to ensure
  # those images are bootable. After some time, remove this version check.
  ZVER="$( zfs version | head -n1 | sed 's/zfs-\(kmod-\)\?//' )"
  if [ -n "${ZVER}" ] && printf '%s\n' "${ZVER}" "2.0" | sort -VCr; then
    NEWZFS=yes
  else
    NEWZFS=""
  fi

  if [ -n "${NEWZFS}" ] && [ -e /etc/hostid ]; then
    # With zfs >= 2.0, prefer the hostid file if it exists
    inst /etc/hostid
  elif HOSTID="$( hostid 2>/dev/null )"; then
    # Fall back to `hostid` output when it is nonzero or with zfs < 2.0
    if [ -z "${NEWZFS}" ]; then
      # In zfs < 2.0, zgenhostid does not provide necessary behavior
      # shellcheck disable=SC2154
      echo -ne "\\x${HOSTID:6:2}\\x${HOSTID:4:2}\\x${HOSTID:2:2}\\x${HOSTID:0:2}" > "${initdir}/etc/hostid"
    elif [ "${HOSTID}" != "00000000" ]; then
      # In zfs >= 2.0, zgenhostid writes the output, but only with nonzero hostid
      # shellcheck disable=SC2154
      zgenhostid -o "${initdir}/etc/hostid" "${HOSTID}"
    fi
  fi

  # shellcheck disable=SC2154
  if [ -e "${initdir}/etc/hostid" ] && type mark_hostonly >/dev/null 2>&1; then
    mark_hostonly /etc/hostid
  fi
}
