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
    "zdb"
    "lsblk"
    "hostid"
    "mount"
    "mount.zfs"
    "kexec"
    "mkdir"
    "tput"
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
    "insmod"
    "modinfo"
    "lsmod"
    "depmod"
  )

  for _exec in "${essential_execs[@]}"; do
    if ! dracut_install "${_exec}"; then
      dfatal "failed to install essential executable '${_exec}'"
      exit 1
    fi
  done

  if ! dracut_install fzf; then
    dfatal "failed to install fzf"
    exit 1
  fi

  # BE clones will work (silently and less efficiently) without mbuffer
  if ! dracut_install mbuffer; then
    dwarning "mbuffer not found; ZFSBootMenu cannot show progress during BE clones"
  fi

  # Workaround for zfsonlinux/zfs#4749 by ensuring libgcc_s.so(.1) is included
  _ret=0
  # If zpool requires libgcc_s.so*, dracut will track and include it
  if ! ldd "$( command -v zpool )" | grep -qF 'libgcc_s.so'; then
    # On systems with gcc-config (Gentoo, Funtoo, etc.), use it to find libgcc_s
    if command -v gcc-config >/dev/null 2>&1; then
      dracut_install "/usr/lib/gcc/$(s=$(gcc-config -c); echo "${s%-*}/${s##*-}")/libgcc_s.so.1"
      _ret=$?
    # Otherwise, use dracut's library installation function to find the right one
    elif ! inst_libdir_file "libgcc_s.so*"; then
      # If all else fails, just try looking for some gcc arch directory
      dracut_install /usr/lib/gcc/*/*/libgcc_s.so*
      _ret=$?
    fi
  fi

  if [ ${_ret} -ne 0 ]; then
    dfatal "Unable to install libgcc_s.so"
    exit 1
  fi

  # shellcheck disable=SC2154
  while read -r doc ; do
    relative="${doc//${moddir}\//}"
    inst_simple "${doc}" "/usr/share/docs/${relative}"
  done <<<"$( find "${moddir}/help-files" -type f )"

  _ret=0

  # Core ZFSBootMenu functionality
  # shellcheck disable=SC2154
  for _lib in "${moddir}"/lib/*; do
    inst_simple "${_lib}" "/lib/$( basename "${_lib}" )" || _ret=$?
  done

  # Helper tools not intended for direct human consumption
  for _libexec in "${moddir}"/libexec/*; do
    inst_simple "${_libexec}" "/libexec/$( basename "${_libexec}" )" || _ret=$?
  done

  # User-facing utilities, useful for running in a recover shell
  for _bin in "${moddir}"/bin/*; do
    inst_simple "${_bin}" "/bin/$( basename "${_bin}" )" || _ret=$?
  done

  # Hooks necessary to initialize ZBM
  inst_hook cmdline 15 "${moddir}/hook/zfsbootmenu-make-finished.sh" || _ret=$?
  inst_hook cmdline 95 "${moddir}/hook/zfsbootmenu-parse-commandline.sh" || _ret=$?
  inst_hook pre-mount 90 "${moddir}/hook/zfsbootmenu-preinit.sh" || _ret=$?

  # Hooks to force the dracut event loop to fire at least once
  # Things like console configuration are done in optional event-loop hooks
  inst_hook initqueue/settled 99 "${moddir}/hook/zfsbootmenu-ready-set.sh" || _ret=$?
  # The initqueue/finished hook is now created at run-time via zfsbootmenu-make-finished.sh

  # If tracing is enabled, build in the full-weight profiling library
  if [ -n "${zfsbootmenu_trace_enable}" ]; then
    inst_simple "${moddir}/profiling/profiling-lib.sh" "/lib/profiling-lib.sh"

    # shellcheck disable=SC2154
    cat << EOF >> "${initdir}/etc/profiling.conf"
export zfsbootmenu_trace_term=${zfsbootmenu_trace_term}
export zfsbootmenu_trace_baud=${zfsbootmenu_trace_baud}
EOF

    # optionally enable early Dracut profiling
    if [ -n "${dracut_trace_enable}" ]; then
      inst_hook cmdline 00 "${moddir}/profiling/profiling-lib.sh"
    fi
  else
    # Install the default profiling library that is a simple `return 0`
    echo "return 0" > "${initdir}/lib/profiling-lib.sh"
  fi

  # Install "early setup" hooks
  # shellcheck disable=SC2154
  if [ -n "${zfsbootmenu_early_setup}" ]; then
    for _exec in ${zfsbootmenu_early_setup}; do
      if [ -x "${_exec}" ]; then
        inst_simple "${_exec}" "/libexec/early-setup.d/$(basename "${_exec}")" || _ret=$?
      else
        dwarning "setup script (${_exec}) missing or not executable; cannot install"
      fi
    done
  fi

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

  # zpool.cache, vdev_id.conf and hostid files are host-specific
  # and do not belong in public release images
  if [ -z "${release_build}" ]; then
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
    if [ "${ival}" = "3300" ]; then
      endian="be"
    else
      if [ "${ival}" != "0033" ]; then
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
  fi

  # shellcheck disable=SC2154
  if [ -e "${initdir}/etc/hostid" ] && type mark_hostonly >/dev/null 2>&1; then
    mark_hostonly /etc/hostid
  fi

  # Check if fuzzy finder supports the refresh-preview flag
  # Added in fzf 0.22.0
  if command -v fzf >/dev/null 2>&1 && \
    echo "abc" | fzf -f "abc" --bind "alt-l:refresh-preview" --exit-0 >/dev/null 2>&1
  then
    has_refresh=1
  else
    has_refresh=
  fi

  # shellcheck disable=SC2154
  cat << 'EOF' > "${initdir}/etc/zfsbootmenu.conf"
# Include guard
[ -n "${_ETC_ZFSBOOTMENU_CONF}" ] && return
readonly _ETC_ZFSBOOTMENU_CONF=1
EOF

  # Collect all of our build-time feature flags
  # shellcheck disable=SC2154
  cat << EOF >> "${initdir}/etc/zfsbootmenu.conf"
export BYTE_ORDER=${endian:-le}
export HAS_REFRESH=${has_refresh}
EOF

  # Embed a kernel command line in the initramfs
  # shellcheck disable=SC2154
  if [ -n "${embedded_kcl}" ]; then
    echo "export embedded_kcl=\"${embedded_kcl}\"" >> "${initdir}/etc/zfsbootmenu.conf"
  fi

  # Force rd.hostonly=0 in the KCL for releases, this will purge itself after 99base/init.sh runs
  # shellcheck disable=SC2154
  if [ -n "${release_build}" ]; then
    echo "rd.hostonly=0" > "${initdir}/etc/cmdline.d/hostonly.conf"
  fi

  # Setup a default environment for all login shells
  cat << EOF >> "${initdir}/etc/profile"
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
export TERM=linux
export HOME=/root
EOF

  # Setup a default environment for bash -i
  cat << EOF >> "${initdir}/root/.bashrc"
source /etc/zfsbootmenu.conf >/dev/null 2>&1
source /lib/kmsg-log-lib.sh >/dev/null 2>&1
source /lib/zfsbootmenu-core.sh >/dev/null 2>&1
source /lib/zfsbootmenu-kcl.sh >/dev/null 2>&1
[ -f /etc/profile ] && source /etc/profile
[ -f /lib/zfsbootmenu-completions.sh ] && source /lib/zfsbootmenu-completions.sh

export PS1="\033[0;33mzfsbootmenu\033[0m \w > "

alias clear="tput clear"
alias reset="tput reset"
alias zbm="zfsbootmenu"
alias logs="ztrace"
alias trace="ztrace"
alias debug="ztrace"
alias help="/libexec/zfsbootmenu-help -L recovery-shell"

zdebug "sourced /root/.bashrc" || true

EOF

  # symlink to .profile for /bin/sh - launched by dropbear
  ln -s "/root/.bashrc" "${initdir}/root/.profile"
}
