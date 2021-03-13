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
    "90-zfs.rules"
    "69-vdev.rules"
    "60-zvol.rules"
  )

  for _rule in "${udev_rules[@]}"; do
    if ! inst_rules "${_rule}"; then
      dfatal "failed to install udev rule '${_rule}'"
      exit 1
    fi
  done

  local essential_execs=(
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
    "ps"
    "env"
    "chmod"
    "od"
    "stty"
  )

  for _exec in "${essential_execs[@]}"; do
    if ! dracut_install "${_exec}"; then
      dfatal "failed to install essential executable '${_exec}'"
      exit 1
    fi
  done

  # sk can be used as a substitute for fzf
  if dracut_install fzf; then
    FUZZY_FIND="fzf"
  elif dracut_install sk; then
    FUZZY_FIND="sk"
  else
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
  inst_simple "${moddir}/zfsbootmenu-preview.sh" "/libexec/zfsbootmenu-preview" || _ret=$?
  inst_simple "${moddir}/zfsbootmenu-input.sh" "/libexec/zfsbootmenu-input" || _ret=$?
  inst_simple "${moddir}/zfsbootmenu-help.sh" "/libexec/zfsbootmenu-help" || _ret=$?
  inst_simple "${moddir}/zfs-chroot.sh" "/bin/zfs-chroot" || _ret=$?
  inst_simple "${moddir}/zfsbootmenu.sh" "/bin/zfsbootmenu" || _ret=$?
  inst_simple "${moddir}/zlogtail.sh" "/bin/zlogtail" || _ret=$?
  inst_hook cmdline 95 "${moddir}/zfsbootmenu-parse-commandline.sh" || _ret=$?
  inst_hook pre-mount 90 "${moddir}/zfsbootmenu-exec.sh" || _ret=$?

  # Install "setup" hooks
  # shellcheck disable=SC2154
  if [ -n "${zfsbootmenu_setup}" ]; then
    for _exec in ${zfsbootmenu_setup}; do
      if [ -x "${_exec}" ]; then
        inst_simple "${_exec}" "/libexec/setup.d/$(basename "${_exec}")" || _ret=$?
      else
        dwarning "setup script (${_exec}) missing or not executable; cannot install"
      fi
    done
  fi

  # Install "teardown" hooks
  # shellcheck disable=SC2154
  if [ -n "${zfsbootmenu_teardown}" ]; then
    for _exec in ${zfsbootmenu_teardown}; do
      if [ -x "${_exec}" ]; then
        inst_simple "${_exec}" "/libexec/teardown.d/$(basename "${_exec}")" || _ret=$?
      else
        dwarning "teardown script (${_exec}) missing or not executable; cannot install"
      fi
    done
  fi

  if [ ${_ret} -ne 0 ]; then
    dfatal "Unable to install core ZFSBootMenu functions"
    exit 1
  fi

  # Optionally install tmux
  # shellcheck disable=SC2154
  if [ "${zfsbootmenu_tmux}" = true ]; then
    # user-defined configuration file
    if [ -n "${zfsbotmenu_tmux_conf}" ] && [ -e "${zfsbootmenu_tmux_conf}" ]; then
      tmux_conf="${zfsbootmenu_tmux_conf}"
    # default file shipped with zfsbootmenu
    elif [ -e "${moddir}/tmux.conf" ]; then
      tmux_conf="${moddir}/tmux.conf"
    fi

    # Only attempt to install if we have a configuration file available
    if [ -n "${tmux_conf}" ] ; then
      dracut_install tmux
      inst_simple "${tmux_conf}" "/etc/tmux.conf"

      # glibc locale file
      if [ -e "/usr/lib/locale/locale-archive" ]; then
        inst_simple "/usr/lib/locale/locale-archive" "/usr/lib/locale/locale-archive"
      fi
    fi
  fi

  if [ -e /etc/zfs/zpool.cache ]; then
    inst /etc/zfs/zpool.cache
    type mark_hostonly >/dev/null 2>&1 && mark_hostonly /etc/zfs/zpool.cache
  fi

  if [ -e /etc/zfs/vdev_id.conf ]; then
    inst /etc/zfs/vdev_id.conf
    type mark_hostonly >/dev/null 2>&1 && mark_hostonly /etc/zfs/vdev_id.conf
  fi

  # Determine platform endianness, defaulting to le
  ival="$( echo -n 3 | od -tx2 -N2 -An | tr -d '[:space:]' )"
  if [ "x${ival}" = "x3300" ]; then
    endian="be"
  else
    if [ "x${ival}" != "x0033" ]; then
      warn "unable to determine platform endianness; assuming little-endian"
    fi
    endian="le"
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
      if [ "${endian}" = "be" ] ; then
        echo -ne "\\x${HOSTID:0:2}\\x${HOSTID:2:2}\\x${HOSTID:4:2}\\x${HOSTID:6:2}" > "${initdir}/etc/hostid"
      else
        echo -ne "\\x${HOSTID:6:2}\\x${HOSTID:4:2}\\x${HOSTID:2:2}\\x${HOSTID:0:2}" > "${initdir}/etc/hostid"
      fi
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

  # Check if dmesg supports --noescape
  if dmesg --noescape -V >/dev/null 2>&1 ; then
    has_escape=1
  else
    has_escape=
  fi

  # Check if fuzzy finder supports the refresh-preview flag
  # Added in fzf 0.22.0
  if command -v "${FUZZY_FIND}" >/dev/null 2>&1 && \
    echo "abc" | "${FUZZY_FIND}" -f "abc" --bind "alt-l:refresh-preview" --exit-0 >/dev/null 2>&1
  then
    has_refresh=1
  else
    has_refresh=
  fi

  # Check if fuzzy finder supports the --info= flag
  # Added in fzf 0.19.0
  if command -v "${FUZZY_FIND}" >/dev/null 2>&1 && \
    echo "abc" | "${FUZZY_FIND}" -f "abc" --info=hidden --exit-0 >/dev/null 2>&1
  then
    has_info=1
  else
    has_info=
  fi

  # Collect all of our build-time feature flags
  # shellcheck disable=SC2154
  cat << EOF > "${initdir}/etc/zfsbootmenu.conf"
export BYTE_ORDER=${endian}
export HAS_NOESCAPE=${has_escape}
export HAS_REFRESH=${has_refresh}
export HAS_INFO=${has_info}
EOF
}
