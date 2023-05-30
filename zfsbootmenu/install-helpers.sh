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

  cat > "${BUILDROOT}/etc/zfsbootmenu.conf" <<-'EOF'
	# Include guard
	[ -n "${_ETC_ZFSBOOTMENU_CONF}" ] && return
	readonly _ETC_ZFSBOOTMENU_CONF=1
	EOF

  cat >> "${BUILDROOT}/etc/zfsbootmenu.conf" <<-EOF
	export HAS_REFRESH="${has_refresh}"
	export HAS_DISABLED="${has_disabled}"
	export HAS_BORDER="${has_border}"
	export HAS_COLUMN="${has_column}"
	EOF
}

create_zbm_profiles() {
  # Create shell profiles for ZBM

  cat > "${BUILDROOT}/etc/profile" <<-EOF
	export PATH=/usr/sbin:/usr/bin:/sbin:/bin
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

	export PS1="\[\033[0;33m\]zfsbootmenu\[\033[0m\] \w > "

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
  ln -s "/root/.bashrc" "${BUILDROOT}/root/.profile"
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

  case "${BUILDSTYLE}" in
    initcpio)
      add_file "${zbm_prof_lib}" "/lib/profiling-lib.sh"
      ;;
    dracut)
      inst_simple "${zfsbootmenu_module_root}/profiling/profiling-lib.sh" "/lib/profiling-lib.sh"
      ;;
    *)
      ;;
  esac

  # shellcheck disable=SC2154
  cat > "${BUILDROOT}/etc/profiling.conf" <<-EOF
	export zfsbootmenu_trace_term=${zfsbootmenu_trace_term}
	export zfsbootmenu_trace_baud=${zfsbootmenu_trace_baud}
	EOF
}
