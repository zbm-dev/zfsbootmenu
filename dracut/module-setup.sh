#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

check() {
  # Do not include this module by default; it must be requested
  return 255
}

depends() {
  echo bash udev-rules
  return 0
}

installkernel() {
  local mod

  # shellcheck disable=SC2154
  for mod in "${zfsbootmenu_essential_modules[@]}"; do
    if ! instmods -c "${mod}" ; then
      dfatal "Required kernel module '${mod}' is missing, aborting image creation!"
      exit 1
    fi
  done

  # shellcheck disable=SC2154
  for mod in "${zfsbootmenu_optional_modules[@]}"; do
    instmods "${mod}"
  done
}

install() {
  : "${zfsbootmenu_module_root:=/usr/share/zfsbootmenu}"

  # shellcheck disable=SC1091
  if ! source "${zfsbootmenu_module_root}/install-helpers.sh" ; then
    dfatal "Unable to source ${zfsbootmenu_module_root}/install-helpers.sh"
    exit 1
  fi

  # BUILDROOT is an initcpio-ism
  # shellcheck disable=SC2154,2034
  BUILDROOT="${initdir}"
  # shellcheck disable=SC2034
  BUILDSTYLE="dracut"

  local _rule _exec _ret

  # shellcheck disable=SC2154
  for _rule in "${zfsbootmenu_udev_rules[@]}"; do
    if ! inst_rules "${_rule}"; then
      dfatal "failed to install udev rule '${_rule}'"
      exit 1
    fi
  done

  # shellcheck disable=SC2154
  for _exec in "${zfsbootmenu_essential_binaries[@]}"; do
    if ! dracut_install "${_exec}"; then
      dfatal "failed to install essential executable '${_exec}'"
      exit 1
    fi
  done

  # shellcheck disable=SC2154
  for _exec in "${zfsbootmenu_optional_binaries[@]}"; do
    if ! dracut_install "${_exec}"; then
      dwarning "optional component '${_exec}' not found, omitting from image"
    fi
  done

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
    relative="${doc//${zfsbootmenu_module_root}\//}"
    inst_simple "${doc}" "/usr/share/docs/${relative}"
  done <<<"$( find "${zfsbootmenu_module_root}/help-files" -type f )"

  compat_dirs=( "/etc/zfs/compatibility.d" "/usr/share/zfs/compatibility.d/" )
  for compat_dir in "${compat_dirs[@]}"; do
    # shellcheck disable=2164
    [ -d "${compat_dir}" ] && tar -cf - "${compat_dir}" | ( cd "${initdir}" ; tar xfp - )
  done
  _ret=0

  # Core ZFSBootMenu functionality
  # shellcheck disable=SC2154
  for _lib in "${zfsbootmenu_module_root}"/lib/*; do
    inst_simple "${_lib}" "/lib/$( basename "${_lib}" )" || _ret=$?
  done

  # Helper tools not intended for direct human consumption
  for _libexec in "${zfsbootmenu_module_root}"/libexec/*; do
    inst_simple "${_libexec}" "/libexec/$( basename "${_libexec}" )" || _ret=$?
  done

  # User-facing utilities, useful for running in a recover shell
  for _bin in "${zfsbootmenu_module_root}"/bin/*; do
    inst_simple "${_bin}" "/bin/$( basename "${_bin}" )" || _ret=$?
  done

  # Hooks necessary to initialize ZBM
  inst_hook cmdline 95 "${zfsbootmenu_module_root}/hook/zfsbootmenu-parse-commandline.sh" || _ret=$?
  inst_hook pre-mount 90 "${zfsbootmenu_module_root}/hook/zfsbootmenu-preinit.sh" || _ret=$?

  # Hooks to force the dracut event loop to fire at least once
  # Things like console configuration are done in optional event-loop hooks
  inst_hook initqueue/settled 99 "${zfsbootmenu_module_root}/hook/zfsbootmenu-ready-set.sh" || _ret=$?
  inst_hook initqueue/finished 99 "${zfsbootmenu_module_root}/hook/zfsbootmenu-ready-chk.sh" || _ret=$?

  # optionally enable early Dracut profiling
  if [ -n "${dracut_trace_enable}" ]; then
    inst_hook cmdline 00 "${zfsbootmenu_module_root}/profiling/profiling-lib.sh"
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

  # vdev_id.conf and hostid files are host-specific
  # and do not belong in public release images
  if [ -z "${release_build}" ]; then
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
        echo -ne "\\x${HOSTID:6:2}\\x${HOSTID:4:2}\\x${HOSTID:2:2}\\x${HOSTID:0:2}" > "${initdir}/etc/hostid"
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

  create_zbm_conf
  create_zbm_profiles
  create_zbm_traceconf
}
