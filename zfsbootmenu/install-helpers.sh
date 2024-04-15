#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# shellcheck disable=SC2034
zfsbootmenu_essential_binaries=(
  "bash"
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
  "tac"
  "blkid"
  "awk"
  "ps"
  "env"
  "chmod"
  "chroot"
  "od"
  "stty"
  "insmod"
  "modinfo"
  "lsmod"
  "depmod"
  "dmesg"
  "fzf"
  "setsid"
  "cat"
)

# shellcheck disable=SC2034
zfsbootmenu_optional_binaries=(
  "mbuffer"
  "column"
  "less"
)

# shellcheck disable=SC2034
zfsbootmenu_udev_rules=(
  "90-zfs.rules"
  "69-vdev.rules"
  "60-zvol.rules"
)

# shellcheck disable=SC2034
zfsbootmenu_essential_modules=(
  "zfs"
  "zcommon"
  "znvpair"
  "zavl"
  "zunicode"
  "zlua"
  "icp"
  "spl"
)

# shellcheck disable=SC2034
zfsbootmenu_optional_modules=(
  "zlib_deflate"
  "zlib_inflate"
  "fat"
  "vfat"
  "nls_iso8859_1"
  "nls_cp437"
)

create_zbm_conf() {
  # Create core ZBM configuration file

  # Check if fuzzy finder supports the refresh-preview flag
  # Added in fzf 0.22.0
  local has_refresh
  if echo "abc" | fzf -f "abc" --bind "alt-l:refresh-preview" --exit-0 >/dev/null 2>&1; then
    has_refresh=1
  fi

  # Check if fuzzy finder supports the disabled flag
  # Added in fzf 0.25.0
  local has_disabled
  if echo "abc" | fzf -f "abc" --disabled --exit-0 >/dev/null 2>&1; then
    has_disabled=1
  fi

  # Check if fuzzy finder supports border flags
  # Added in fzf 0.35.0
  local has_border
  if echo "abc" | fzf -f "abc" --border-label=test --exit-0 >/dev/null 2>&1; then
    has_border=1
  fi

  local has_column
  if command -v column >/dev/null 2>&1 ; then
    has_column=1
  fi

  case "${zfsbootmenu_release_build,,}" in
    yes|y|on|1)
      zfsbootmenu_release_build=1
      ;;
    *)
      zfsbootmenu_release_build=
      ;;
  esac

  # Normalize ZBM_BUILDSTYLE, if set
  case "${ZBM_BUILDSTYLE,,}" in
    mkinitcpio) ZBM_BUILDSTYLE="mkinitcpio" ;;
    dracut) ZBM_BUILDSTYLE="dracut" ;;
    *) ZBM_BUILDSTYLE="" ;;
  esac

  cat > "${BUILDROOT}/etc/zfsbootmenu.conf" <<-'EOF'
	# Include guard
	[ -n "${_ETC_ZFSBOOTMENU_CONF}" ] && return
	readonly _ETC_ZFSBOOTMENU_CONF=1
	EOF

  # shellcheck disable=SC2154
  cat >> "${BUILDROOT}/etc/zfsbootmenu.conf" <<-EOF
	export HAS_REFRESH="${has_refresh}"
	export HAS_DISABLED="${has_disabled}"
	export HAS_BORDER="${has_border}"
	export HAS_COLUMN="${has_column}"
	export ZBM_BUILDSTYLE="${ZBM_BUILDSTYLE}"
	export ZBM_RELEASE_BUILD="${zfsbootmenu_release_build}"
	EOF
}

create_zbm_profiles() {
  # Create shell profiles for ZBM

  cat > "${BUILDROOT}/etc/profile" <<-EOF
	export PATH=/zbm/bin:/usr/sbin:/usr/bin:/sbin:/bin
	export TERM=linux
	export HOME=/root
	EOF

  mkdir -p "${BUILDROOT}/root"
  cat > "${BUILDROOT}/root/.bashrc" <<-EOF
	source /etc/zfsbootmenu.conf >/dev/null 2>&1
	source /lib/kmsg-log-lib.sh >/dev/null 2>&1
	source /lib/zfsbootmenu-core.sh >/dev/null 2>&1
	source /lib/zfsbootmenu-kcl.sh >/dev/null 2>&1
	[ -f /etc/profile ] && source /etc/profile
	[ -f /lib/zfsbootmenu-completions.sh ] && source /lib/zfsbootmenu-completions.sh

	export PROMPT_COMMAND="/libexec/recovery-error-printer"
	export PS1='\[\033[0;33m\]zfsbootmenu\[\033[0m\] \w > '

	alias clear="tput clear"
	alias reset="tput reset"
	alias trace="ztrace"
	alias help="/libexec/zfsbootmenu-help -L recovery-shell"

	zdebug "sourced /root/.bashrc" || true
	EOF

  # symlink to .profile for /bin/sh - launched by dropbear
  ln -s "/root/.bashrc" "${BUILDROOT}/root/.profile"
}

zbm_install_symlink() {
  [ -L "${1}" ] || return 1

  # shellcheck disable=SC2154
  case "${1}" in
    "${zfsbootmenu_module_root}"/*) ;;
    *) return 1 ;;
  esac

  local dest src

  dest="$(readlink "${1}")" || dest=
  [ -n "${dest}" ] || return 1

  case "${dest}" in
    /*) return 1 ;;
  esac

  src="${2:-"${1}"}"

  # Attempt to install the target of the symlink
  local rpath
  if rpath="$(realpath -f "${1}")"; then
    if [ -e "${rpath}" ] && [ ! -L "${rpath}" ]; then
      zbm_install_file "${rpath}" "$(dirname "${src}")/${dest}" || return 1
    fi
  fi

  ln -Ts "${dest}" "${BUILDROOT}/${src}" || return 1
  return 0
}

zbm_install_file() {
  # All symlinks in the ZBM module root should be relative
  zbm_install_symlink "$@" && return 0

  case "${ZBM_BUILDSTYLE,,}" in
    mkinitcpio)
      if ! add_file "${1}" "${2}"; then
        error "failed to install file '${1}'"
        return 1
      fi
      ;;
    dracut)
      if ! inst_simple "${1}" "${2}"; then
        dfatal "failed to install file '${1}'"
        return 1
      fi
      ;;
    *)
      echo "ERROR: unrecognized build style; unable to install files" >&2
      return 1
      ;;
  esac
}

create_zbm_traceconf() {
  local zbm_prof_lib

  # Enable performance profiling if configured and available
  # shellcheck disable=SC2154
  case "${zfsbootmenu_trace_enable,,}" in
    yes|y|on|1)
      zbm_prof_lib="${zfsbootmenu_module_root}/profiling/profiling-lib.sh"
      ;;
    *)
      ;;
  esac

  if ! [ -r "${zbm_prof_lib}" ]; then
    echo "return 0" > "${BUILDROOT}/lib/profiling-lib.sh"
    return
  fi

  zbm_install_file "${zbm_prof_lib}" "/lib/profiling-lib.sh"

  # shellcheck disable=SC2154
  cat > "${BUILDROOT}/etc/profiling.conf" <<-EOF
	export zfsbootmenu_trace_term=${zfsbootmenu_trace_term}
	export zfsbootmenu_trace_baud=${zfsbootmenu_trace_baud}
	EOF
}


install_zbm_core() {
  local cdir cfile ret

  ret=0
  for cdir in lib libexec bin; do
    for cfile in "${zfsbootmenu_module_root}/${cdir}"/*; do
      zbm_install_file "${cfile}" "/${cdir}/${cfile##*/}" || ret=$?
    done
  done

  for cfile in "${zfsbootmenu_module_root}/init.d"/*; do
    zbm_install_file "${cfile}" "/libexec/init.d/${cfile##*/}" || ret=$?
  done

  return $ret
}


install_zbm_docs() {
  local doc relative ret

  ret=0
  while read -r doc; do
    relative="${doc#"${zfsbootmenu_module_root}"}"
    [ "${relative}" = "${doc}" ] && continue
    relative="${relative#/}"
    zbm_install_file "${doc}" "/usr/share/docs/${relative}" || ret=$?
  done <<< "$( find "${zfsbootmenu_module_root}/help-files" -type f )"

  return $ret
}

install_zbm_fonts() {

  [ -d "${zfsbootmenu_module_root}/fonts" ] || return 1

  # Install into a non-standard path so that the Dracut i18n module doesn't stomp over our custom fonts

  for font in "${zfsbootmenu_module_root}/fonts"/*.psf; do
    [ -f "${font}" ] && zbm_install_file "${font}" "/usr/share/zfsbootmenu/fonts/${font##*/}"
  done
}

install_zbm_osver() {
  local build_date
  [ -r "${zfsbootmenu_module_root}/zbm-release" ] || return 0
  zbm_install_file "${zfsbootmenu_module_root}/zbm-release" "/etc/zbm-release"
  if build_date="$(date '+%Y-%m-%d')"; then
    cat >> "${BUILDROOT}/etc/zbm-release" <<-EOF
	BUILD_ID="${build_date}"
	EOF
  fi

  ln -Tsf zbm-release "${BUILDROOT}/etc/os-release"
}

populate_hook_dir() {
  local hfile ret hlev

  hlev="${1}"
  if [ -z "${hlev}" ]; then
    echo "ERROR: a hook level is required" >&2
    return 1
  fi

  shift
  [ "$#" -gt 0 ] || return 0

  mkdir -p "${BUILDROOT}/libexec/hooks/${hlev}" || return 1

  ret=0
  for hfile in "$@"; do
    [ -x "${hfile}" ] || continue
    zbm_install_file "${hfile}" "/libexec/hooks/${hlev}/${hfile##*/}" || ret=$?
  done

  return $ret
}


install_zbm_hooks() {
  local hdir hsrc hfile ret stages

  ret=0

  stages=( early-setup.d setup.d load-key.d boot-sel.d teardown.d )

  # Install system hooks first so user options can override them
  for hdir in "${stages[@]}"; do
    hsrc="${zfsbootmenu_module_root}/hooks/${hdir}"
    [ -d "${hsrc}" ] || continue
    populate_hook_dir "${hdir}" "${hsrc}"/* || ret=$?
  done

  # Install user hooks via deprecated syntax first

  # shellcheck disable=SC2154
  if [[ "${zfsbootmenu_early_setup@a}" != *a* ]]; then
    # shellcheck disable=SC2086
    populate_hook_dir "early-setup.d" ${zfsbootmenu_early_setup} || ret=$?
  else
    populate_hook_dir "early-setup.d" "${zfsbootmenu_early_setup[@]}" || ret=$?
  fi

  # shellcheck disable=SC2154
  if [[ "${zfsbootmenu_setup@a}" != *a* ]]; then
    # shellcheck disable=SC2086
    populate_hook_dir "setup.d" ${zfsbootmenu_setup} || ret=$?
  else
    populate_hook_dir "setup.d" "${zfsbootmenu_setup[@]}" || ret=$?
  fi

  # shellcheck disable=SC2154
  if [[ "${zfsbootmenu_teardown@a}" != *a* ]]; then
    # shellcheck disable=SC2086
    populate_hook_dir "teardown.d" ${zfsbootmenu_teardown} || ret=$?
  else
    populate_hook_dir "teardown.d" "${zfsbootmenu_teardown[@]}" || ret=$?
  fi

  # Install user hooks using the preferred zfsbootmenu_hook_root mechanism
  for hdir in "${stages[@]}"; do
    # shellcheck disable=SC2154
    hsrc="${zfsbootmenu_hook_root}/${hdir}"
    [ -d "${hsrc}" ] || continue
    populate_hook_dir "${hdir}" "${hsrc}"/* || ret=$?
  done

  return $ret
}


find_libgcc_s() {
  local f libdirs libbase ldir zlibs matched

  # Skip detection if desired
  # shellcheck disable=SC2154
  case "${zfsbootmenu_skip_gcc_s,,}" in
    yes|on|1) return 0 ;;
  esac

  # This is only required on glibc systems due to a dlopen in pthread_cancel
  # https://github.com/openzfs/zfs/commit/24554082bd93cb90400c4cb751275debda229009
  ldconfig -p 2>/dev/null | grep -qF 'libc.so.6' || return 0

  # Build a list of libraries linked by zpool
  zlibs="$( ldd "$( command -v zpool 2>/dev/null )" )" || zlibs=

  # If zpool links libgcc_s overtly, there is no need for further action
  if grep -qF 'libgcc_s.so' <<< "${zlibs}"; then
    return 0
  fi

  # Query gcc-config for a current runtime profile if possible
  if command -v gcc-config >/dev/null 2>&1; then
    local gver
    if gver="$( gcc-config -c )"; then
      for f in "/usr/lib/gcc/${gver%-*}/${gver##*-}"/libgcc_s.so*; do
        [ -e "${f}" ] || continue
        echo "${f}"
        matched="yes"
      done
      [ -n "${matched}" ] && return 0
    fi
  fi

  # Try walking library paths to find libgcc_s

  # Search the system cache (adapted from dracut)
  libdirs="$( ldconfig -pN 2>/dev/null \
              | grep -E -v '/(lib|lib64|usr/lib|usr/lib64)/[^/]*$' \
              | sed -n 's,.* => \(.*\)/.*,\1,p' | sort | uniq )" || libdirs=""

  # Search zpool dependencies to figure out system libdirs
  if [[ "${zlibs}" == */lib64/* ]]; then
    libbase="lib64"
  else
    libbase="lib"
  fi

  # Look in all possible system library directories
  libdirs="/${libbase} /usr/${libbase} ${libdirs}"
  for ldir in ${libdirs}; do
    for f in "${ldir}"/libgcc_s.so*; do
      [ -e "${f}" ] || continue
      echo "${f}"
      matched="yes"
    done
  done
  [ -n "${matched}" ] && return 0

  # As a final fallback, just try to grab *any* libgcc_s from GCC
  for f in /usr/lib/gcc/*/*/libgcc_s.so*; do
    [ -f "${f}" ] || continue
    echo "${f}"
    matched="yes"
  done

  [ -n "${matched}" ] && return 0
  return 1
}
