#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# Include guard
[ -n "${_ZFSBOOTMENU_CORE}" ] && return
readonly _ZFSBOOTMENU_CORE=1

# shellcheck disable=1091
if ! source /lib/zfsbootmenu-kcl.sh >/dev/null 2>&1; then
  zerror "failed to load KCL manipulation functions"
  exit 1
fi

# arg1: text with color sequences
# prints: text with color sequences removed
# returns: nothing

decolorize() {
  shopt -s extglob
  echo "${1//+(\\033\[[0-1];3[0-7]m|\\033\[0m|[[:cntrl:]]\[[0-1];3[0-7]m|[[:cntrl:]]\[0m)/}"
  shopt -u extglob
}

# arg1: color name
# arg2...argN: text to color
# prints: text with color escape codes
# returns: nothing

colorize() {
  local color
  color="${1}"
  shift
  case "${color}" in
    black)        echo -e -n '\033[0;30m' ;;
    red)          echo -e -n '\033[0;31m' ;;
    green)        echo -e -n '\033[0;32m' ;;
    orange)       echo -e -n '\033[0;33m' ;;
    blue)         echo -e -n '\033[0;34m' ;;
    magenta)      echo -e -n '\033[0;35m' ;;
    cyan)         echo -e -n '\033[0;36m' ;;
    lightgray)    echo -e -n '\033[0;37m' ;;
    darkgray)     echo -e -n '\033[1;30m' ;;
    lightred)     echo -e -n '\033[1;31m' ;;
    lightgreen)   echo -e -n '\033[1;32m' ;;
    yellow)       echo -e -n '\033[1;33m' ;;
    lightblue)    echo -e -n '\033[1;34m' ;;
    lightmagenta) echo -e -n '\033[1;35m' ;;
    lightcyan)    echo -e -n '\033[1;36m' ;;
    white)        echo -e -n '\033[1;37m' ;;
    *)            echo -e -n '\033[0m' ;;
  esac
  echo -e -n "$@"
  echo -e -n '\033[0m'
}

# arg1: text to center
# prints: left-padded text
# returns: nothing

center_string() {
  printf "%*s" $(( ( ${#1} + COLUMNS ) / 2 )) "${1}"
}

# arg1: hostid, as hex number without leading "0x"
# prints: nothing
# returns: 0 on successful write, 1 on error

write_hostid() {
  local hostid ret splmod
  splmod="/sys/module/spl/parameters/spl_hostid"

  # Normalize the hostid
  if ! hostid="$( printf "%08x" "0x${1:-0}" 2>/dev/null )"; then
    zerror "invalid hostid $1"
    return 1
  fi


  if echo -ne "\\x${hostid:6:2}\\x${hostid:4:2}\\x${hostid:2:2}\\x${hostid:0:2}" > "/etc/hostid" ; then
    zdebug "wrote hostid ${hostid} to /etc/hostid"
    if [ -w "${splmod}" ]; then
      echo 0 > "${splmod}" || zwarn "failed to force spl.spl_hostid=0 for host ID matching"
    fi
  else
    zerror "unable to write $hostid to /etc/hostid"
    return 1
  fi

  return 0
}

# args: no arguments
# prints: hostid used by the SPL kmod, as hex with 0x prefix
# returns: 0 on successful read, 1 on failure

get_spl_hostid() {
  local spl_hostid

  # Prefer the module parameter if it exists and is nonzero
  if [ -r /sys/module/spl/parameters/spl_hostid ]; then
    read -r spl_hostid < /sys/module/spl/parameters/spl_hostid
    if [ "${spl_hostid}" -ne 0 ]; then
      # Value is decimal, convert to hex for consistency
      zdebug "hostid from spl.spl_hostid: ${spl_hostid}"
      printf "0x%08x" "${spl_hostid}"
      return 0
    fi
  fi

  # Otherwise look to /etc/hostid, if possible
  if [ -r /etc/hostid ] && command -v od >/dev/null 2>&1; then
    spl_hostid="$( od -tx4 -N4 -An /etc/hostid 2>/dev/null )"
    spl_hostid="${spl_hostid//[[:space:]]/}"
    if [ -n "${spl_hostid}" ]; then
      zdebug "hostid from /etc/hostid: ${spl_hostid}"
      echo -n "0x${spl_hostid}"
      return 0
    fi
  fi

  # Finally, fall back to ${BASE}/spl_hostid if a host match was performed
  if [ -r "${BASE}/spl_hostid" ]; then
    read -r spl_hostid < "${BASE}/spl_hostid"
    if [ -n "${spl_hostid}" ]; then
      zdebug "hostid from ${BASE}/spl_hostid: ${spl_hostid}"
      echo -n "0x${spl_hostid}"
      return 0
    fi
  fi

  return 1
}


# arg1: optional specific pool to inspect
# prints: <imported pool>;<hostid>
# returns: 0 on successful pool import, 1 on failure

match_hostid() {
  local importable pool state hostid hostid_re single
  importable=()

  single="${1}"
  hostid_re='hostid=([A-Fa-f0-9]{1,8})'

  if [ -n "${single}" ]; then
    importable+=( "${single}" )
  else
    while read -r line; do
      case "$line" in
        pool*)
          pool="${line#pool: }"
          ;;
        state*)
          state="${line#state: }"
          # shellcheck disable=SC2154
          if [ "${state}" == "ONLINE" ] && [ -n "${pool}" ] && [ "${pool}" != "${zbm_prefer_pool}" ]; then
            importable+=("${pool}")
            pool=""
          fi
          ;;
      esac
    done <<<"$( zpool import 2>/dev/null )"
  fi

  zdebug "importable pools: ${importable[*]}"

  for pool in "${importable[@]}"; do
    zdebug "trying to import: ${pool}"

    if [[ $( zpool import -o readonly=on -N "${pool}" 2>&1 ) =~ $hostid_re ]] ; then
      hostid="$( printf "%08x" "0x${BASH_REMATCH[1]}" )"
      zdebug "discovered pool owner hostid: ${hostid}"
    else
      zdebug "unable to scrape hostid for ${pool}, skipping"
      continue
    fi

    if ! write_hostid "${hostid}"; then
      zdebug "failed to set hostid ${hostid}, skipping import of pool ${pool}"
      continue
    fi

    if read_write='' import_pool "${pool}"; then
      zdebug "successfully imported ${pool}"

      if [ -z "${ZBM_RELEASE_BUILD}" ]; then
        zwarn "imported ${pool} with assumed hostid ${hostid}"
        zwarn "set spl_hostid=${hostid} on ZBM KCL or regenerate with corrected /etc/hostid"
      fi

      echo "${pool};${hostid}"
      return 0
    fi
  done

  # no pools could be imported, we failed to match a hostid
  return 1
}

# args: no arguments
# prints: nothing
# returns: nothing

log_unimportable() {
  local pool id state line error_line

  while read -r line; do
    case "${line}" in
      pool*)
        pool="${line#pool: }"
        ;;
      id*)
        id="${line#id: }"
        ;;
      state*)
        state="${line#state: }"
        if [ "${state}" == "UNAVAIL" ]; then
          while read -r error_line; do
            zerror "${error_line}"
          done <<<"$( zpool import -N "${id}" 2>&1 )"
        fi
        state=
        pool=
        id=
        ;;
      *)
        ;;
    esac
  done <<<"$( zpool import 2>/dev/null )"
}

# args: none
# prints: nothing
# returns: 0 if at least one pool is available

check_for_pools() {
  local pool

  while read -r pool ; do
    [ -n "${pool}" ] && return 0
  done <<<"$( zpool list -H -o name 2>/dev/null )"

  return 1
}

# arg1: device name
# prints: mountpoint
# returns: 0 on success

mount_block() {
  local device mnt output

  device="${1}"

  if [ -z "${device}" ]; then
    zerror "device is undefined"
    return 1
  fi

  if [ ! -b "${device}" ]; then
    zerror "device does not exist or is not a block device"
    return 1
  fi

  if mnt="$( is_mounted "${device}" )"; then
    echo "${mnt}"
    return 0
  fi

  mnt="/mnt/${device##*/}"

  if [ -d "${mnt}" ] && is_mountpoint "${mnt}"; then
    zerror "mountpoint '${mnt}' already in use"
    return 1
  fi

  mkdir -p "${mnt}" || return 1

  if output="$( mount "${device}" "${mnt}" 2>&1 )"; then
    echo "${mnt}"
    return 0
  else
    zerror "unable to mount '${device}' at '${mnt}'"
    zerror "${output}"
    return 1
  fi
}

# arg1: ZFS filesystem name
# prints: mountpoint
# returns: 0 on success
#
# If the filesystem is locked, this method fails without attempting unlock

mount_zfs() {
  local fs rwo mnt ret pool

  fs="${1}"

  if [ -z "${fs}" ]; then
    zerror "fs is undefined"
    return 1
  fi

  if be_is_locked "${fs}" >/dev/null; then
    zerror "${fs} is locked, unable to mount filesystem"
    zdebug "${fs} is locked, returning"
    return 1
  fi

  mnt="$( be_location "${fs}" )/mnt"
  mkdir -p "${mnt}"

  # filesystems are readonly by default, but read-write mounts may be requested
  rwo="ro"

  # shellcheck disable=SC2154
  if [ -n "${allow_rw}" ]; then
    pool="${fs%%/*}"
    if is_snapshot "${fs}" ; then
      zwarn "read-write mount of ${fs} forbidden, filesystem is a snapshot"
    elif is_writable "${pool}" ; then
      rwo="rw"
      zdebug "allowing requested read-write mount of ${fs}"
    else
      zwarn "read-write mount of ${fs} forbidden, pool ${pool} is not writable"
    fi
  fi

  # zfsutil is required for non-legacy mounts and omitted for legacy mounts or snapshots
  if [ "$(zfs get -H -o value mountpoint "${fs}")" = "legacy" ] || is_snapshot "${fs}" ; then
    zdebug "mounting ${fs} at ${mnt} (${rwo})"
    mount -o "${rwo}" -t zfs "${fs}" "${mnt}"
    ret=$?
  else
    zdebug "mounting ${fs} at ${mnt} (${rwo}) with zfsutil"
    zdebug "mount -o zfsutil,${rwo} -t zfs ${fs} ${mnt}"
    mount -o "zfsutil,${rwo}" -t zfs "${fs}" "${mnt}"
    ret=$?
  fi

  echo "${mnt}"
  zdebug "mount return code: ${ret}"
  return ${ret}
}

# arg1: bootfs kernel initramfs
# prints: nothing
# returns: 1 on error, otherwise does not return

kexec_kernel() {
  local selected fs kernel initramfs output hook_envs

  selected="${1}"
  if [ -z "${selected}" ]; then
    zerror "fs, kernel, initramfs undefined"
    return 130
  fi

  # zfs filesystem
  # kernel
  # initramfs
  IFS=$'\t' read -r fs kernel initramfs <<<"${selected}"

  zdebug "fs: ${fs}, kernel: ${kernel}, initramfs: ${initramfs}"

  CLEAR_SCREEN=1 load_key "${fs}"

  tput cnorm
  tput clear

  if ! mnt=$( mount_zfs "${fs}" ); then
    emergency_shell "unable to mount $( colorize cyan "${fs}" )"
    return 1
  fi

  # Variables to tell user hooks what BE has been selected
  hook_envs=(
    ZBM_SELECTED_BE="${fs}"
    ZBM_SELECTED_KERNEL="${kernel}"
    ZBM_SELECTED_INITRAMFS="${initramfs}"
  )

  # Run boot-environment hooks, if they exist
  env "${hook_envs[@]}" \
    ZBM_SELECTED_MOUNTPOINT="${mnt}" \
    /libexec/zfsbootmenu-run-hooks "boot-sel.d"

  cli_args="$( load_be_cmdline "${fs}" )"
  root_prefix="$( find_root_prefix "${fs}" "${mnt}" )"

  if ! output="$( kexec -a -l "${mnt}${kernel}" \
    --initrd="${mnt}${initramfs}" \
    --command-line="${root_prefix}${fs} ${cli_args}" 2>&1 )"
  then
    zerror "unable to load ${mnt}${kernel} and ${mnt}${initramfs} into memory"
    zerror "${output}"
    umount "${mnt}"
    timed_prompt -d 10 \
      -m "$( colorize red 'Unable to load kernel or initramfs into memory' )" \
      -m "$( colorize orange "${mnt}${kernel}" )" \
      -m "$( colorize orange "${mnt}${initramfs}" )"

    return 1
  else
    if zdebug ; then
      zdebug "loaded ${mnt}${kernel} and ${mnt}${initramfs} into memory"
      zdebug "kernel command line: '${root_prefix}${fs} ${cli_args}'"
      zdebug "${output}"
    fi
  fi

  umount "${mnt}"

  while read -r _pool; do
    if is_writable "${_pool}"; then
      zdebug "${_pool} is read/write, exporting"
      export_pool "${_pool}"
    fi
  done <<<"$( zpool list -H -o name )"

  # Run teardown hooks, if they exist
  env "${hook_envs[@]}" /libexec/zfsbootmenu-run-hooks "teardown.d"

  if ! output="$( kexec -e -i 2>&1 )"; then
    zerror "kexec -e -i failed!"
    zerror "${output}"
    timed_prompt -d 10 \
      -m "$( colorize red "kexec run of ${kernel} failed!" )"
    return 1
  fi
}

# arg1: snapshot name
# arg2: new BE name
# prints: nothing
# returns: 0 on success

duplicate_snapshot() {
  local selected target target_parent pool recv_args
  local fs encroot keylocation

  selected="${1}"
  if [ -z "$selected" ]; then
    zerror "selected is undefined"
    return 1
  fi
  zdebug "selected: ${selected}"

  target="${2}"
  if [ -z "$target" ]; then
    zerror "target is undefined"
    return 1
  fi
  zdebug "target: ${target}"

  pool="${selected%%/*}"
  if ! set_rw_pool "${pool}" ; then
    zerror "unable to set pool ${pool} read/write"
    return 1
  fi

  # Make sure both the source and the parent of the target are unlocked
  # NOTE: load_key should work as expected without stripping snapshot from name
  CLEAR_SCREEN=0 load_key "${selected}"

  # It is possible that the target is a top-level filesystem
  # If it is not, the parent might be locked, so make sure to unlock
  target_parent="${target%/*}"
  if [ -n "${target_parent}" ]; then
    CLEAR_SCREEN=0 load_key "${target_parent}"
  fi

  recv_args=( "-u" "-o" "canmount=noauto" "-o" "mountpoint=/" )

  if encroot="$( be_has_encroot "${selected}" )"; then
    keylocation="$( zfs get -H -o value keylocation "${encroot}" 2>/dev/null )"
    if [ -n "${keylocation}" ] && [ "${keylocation}" != "-" ]; then
      recv_args+=( "-o" "keylocation=${keylocation}" )
    fi
  fi

  recv_args+=( "${target}" )

  echo ""

  (
    trap 'exit 0' SIGINT
    if command -v mbuffer >/dev/null 2>&1; then
      # Buffer the exchange when possible
      zfs send -p -w "${selected}" | mbuffer | zfs recv "${recv_args[@]}"
    else
      zfs send -p -w "${selected}" | zfs recv "${recv_args[@]}"
    fi
  ) || return

  echo ""

  # If the source was encrypted, the raw send will have created a new
  # encryption root at the target. Move the encryption root to the parent if
  # the source was not its own encryption root.

  fs="${selected%@*}"
  if [ -z "${encroot}" ] || [ "${encroot}" = "${fs}" ]; then
    return 0
  fi

  if encroot="$( be_has_encroot "${target}" )"; then
    if [ "${encroot}" = "${target}" ]; then
      # Key must be loaded before changing
      CLEAR_SCREEN=0 load_key "${target}"
      zfs change-key -i "${target}"
    fi
  fi
}

# arg1: snapshot name
# arg2: new BE name
# arg3: prevents promotion if equal to "nopromote"; otherwise ignored
# prints: nothing
# returns: 0 on success

clone_snapshot() {
  local selected target pool opts parent

  selected="${1}"
  if [ -z "$selected" ]; then
    zerror "selected is undefined"
    return 1
  fi
  zdebug "selected: ${selected}"

  target="${2}"
  if [ -z "$target" ]; then
    zerror "target is undefined"
    return 1
  fi
  zdebug "target: ${target}"

  pool="${selected%%/*}"
  if ! set_rw_pool "${pool}" ; then
    zerror "unable to set pool ${pool} read/write"
    return 1
  fi

  parent="${selected%%@*}"
  load_key "${parent}"

  while read -r PROPERTY VALUE
  do
    case "${PROPERTY}" in
      "mountpoint")
        # explicitly set in the clone
        ;;
      "canmount")
        # explicitly set in the clone
        ;;
      *)
        zdebug "setting ${PROPERTY}=${VALUE}"
        opts+=("-o" "${PROPERTY}=${VALUE}")
        ;;
    esac
  done <<< "$( zfs get -o property,value -s local,received -H all "${parent}" )"

  # Clone must succeed to continue
  if ! zfs clone -o mountpoint=/ -o canmount=noauto "${opts[@]}" "${selected}" "${target}" ; then
    zerror "clone failed with $?"
    return 1
  fi

  if [ -n "${PROMOTE}" ]; then
    # Promotion must succeed to continue
    zdebug "promoting ${target}"
    if ! zfs promote "${target}"; then
      zerror "unable to promote ${target}"
      return 1
    fi
  fi

  return 0
}

# arg1: filesystem name
# arg2: snapshot name
# prints: nothing
# returns: 0 on success

create_snapshot() {
  local selected target pool

  selected="${1}"
  if [ -z "$selected" ]; then
    zerror "selected is undefined"
    return 1
  fi
  zdebug "selected: ${selected}"

  target="${2}"
  if [ -z "$target" ]; then
    zerror "target is undefined"
    return 1
  fi
  zdebug "target: ${target}"

  pool="${selected%%/*}"
  if ! set_rw_pool "${pool}" ; then
    zerror "unable to set pool ${pool} read/write"
    return 1
  fi

  load_key "${selected}"

  zdebug "creating snapshot ${selected}@${target}"
  if ! output="$( zfs snapshot "${selected}@${target}" 2>&1 )" ; then
    zdebug "unable to create snapshot: ${output}"
    return 1
  fi

  return 0
}

# arg1: snapshot name
# prints: nothing
# returns: 0 on success

rollback_snapshot() {
  local snap pool

  snap="${1}"
  pool="${snap%%/*}"
  if [ "${pool}" = "${snap}" ]; then
    zerror "unable to determine pool for rollback"
    return 1
  fi

  if ! find_be_kernels "${snap}" >/dev/null; then
    timed_prompt -d 10 \
      -m "$( colorize red "Snapshot ${snap} has no kernels, will not roll back" )"\
      -m "$( colorize red "Use a recovery shell to manually force rollback" )"
    return 1
  fi

  tput clear
  tput cnorm
  tput cup 0 0

  cat <<-EOF
	WARNING!!!

	You are attempting to roll back to the snapshot

		$( colorize "red" "${snap}" )

	This will DESTROY curent state and all newer snapshots.

	Type $( colorize "red" "ROLLBACK" ) to proceed with the rollback.

	Type any other text, or just press enter, to abort.

	Proceed $( colorize "red" "[No]" ) ?
	EOF

  decision="$( /libexec/zfsbootmenu-input )"
  if [ "${decision}" != "ROLLBACK" ]; then
    zdebug "aborting rollback by user request"
    return 0
  fi

  # Re-import pool read/write
  if ! set_rw_pool "${pool}"; then
    zerror "unable to set ${pool} read/write"
    return 1
  fi

  # Make sure keys are loaded
  CLEAR_SCREEN=1 load_key "${snap}"

  zdebug "will roll back ${snap}"
  if ! output="$( zfs rollback -r "${snap}" 2>&1 )"; then
    zerror "failed to roll back snapshot ${snap}"
    zerror "${output}"
    return 1
  fi
}

# arg1: ZFS filesystem
# arg2: default kernel path (omit to unset default)
# prints: nothing
# returns: 0 on success, 1 otherwise

set_default_kernel() {
  local fs kernel

  fs="$1"
  if [ -z "${fs}" ]; then
    zerror "fs is undefined"
    return 1
  fi
  zdebug "fs set to ${fs}"

  pool="${fs%%/*}"
  if [ -z "${pool}" ]; then
    zerror "pool is undefined"
    return 1
  fi
  zdebug "pool set to ${pool}"

  # Make sure the pool is writable
  set_rw_pool "${pool}" || return 1
  CLEAR_SCREEN=1 load_key "${fs}"

  # Strip leading /boot/ or / to list only the file
  kernel="${2#/}"
  kernel="${kernel#boot/}"

  # Restore nonspecific default when no kernel specified
  if [ -z "$kernel" ]; then
    zdebug "clearing default kernel"
    zfs inherit org.zfsbootmenu:kernel "${fs}" || return 1
  else
    zdebug "kernel set to ${kernel}"
    zfs set org.zfsbootmenu:kernel="${kernel}$" "${fs}" || return 1
  fi

  return 0
}

# arg1: ZFS filesystem
# prints: nothing
# returns: nothing

set_default_env() {
  local environment pool

  environment="${1}"
  if [ -z "${environment}" ] ; then
    zerror "environment is undefined"
    return 1
  fi
  zdebug "environment set to: ${environment}"

  pool="${environment%%/*}"
  zdebug "pool set to: ${pool}"
  if ! set_rw_pool "${pool}" ; then
    zerror "unable to set pool ${pool} read/write"
    return 1
  fi

  CLEAR_SCREEN=1 load_key "${pool}"

  if zpool set bootfs="${environment}" "${pool}" >/dev/null 2>&1 ; then
    BOOTFS="${environment}"
    zdebug "BOOTFS set to ${BOOTFS}"
  else
    zerror "unable to set bootfs=${environment} on ${pool}"
    return 1
  fi
}

# arg1: path of the kernel for which the initramfs is sought
# prints: path of a matching initramfs
# returns: 0 if initramfs was found, 1 otherwise

find_be_initramfs() {
  local kpath
  local kdir kern kver ifile candidates

  kpath="$1"
  if [ ! -r "${kpath}" ]; then
    zerror "specified kernel does not exist"
    return 1
  fi

  # Split kernel path into file and directory
  kern="${kpath##*/}"
  kdir="${kpath%"${kern}"}"
  kdir="${kdir%/}"
  zdebug "kernel path: '${kpath}', directory: '${kdir}', file: '${kern}'"

  # Kernel "base" extends to first hyphen, "version" follows and may be empty
  kver="${kern#"${kern%%-*}"}"
  zdebug "kernel version: '${kver}'"

  # Try some common cases before doing an exhaustive search

  candidates=(
    # Void, Arch
    "initramfs-${kern}.img"
    "initramfs${kver}.img"

    # Debian and other initramfs-tools users
    "initrd.img-${kern}"
    "initrd.img${kver}"

    # Alpine
    "initramfs-${kern}"
    "initramfs${kver}"
  )

  for ifile in "${candidates[@]}"; do
    if [ -e "${kdir}/${ifile}" ]; then
      zdebug "short-matching '${ifile}' to '${kern}'"
      echo "${kdir}/${ifile}"
      return 0
    fi
  done

  # Common cases have failed, try a more exhaustive search

  local ext pfx lbl ifile

  # Use loops instead of a clever brace-expansion for clarity and control
  for ext in {.img,""}{"",.{gz,bz2,xz,lzma,lz4,lzo,zstd}}; do
    for pfx in initramfs initrd; do
      for lbl in "${kern}" "${kver}"; do
        for ifile in "${pfx}${lbl}${ext}" "${pfx}${ext}${lbl}"; do
          [ -e "${kdir}/${ifile}" ] || continue
          zdebug "matching '${ifile}' to '${kern}'"
          echo "${kdir}/${ifile}"
          return 0
        done
      done
    done
  done

  return 1
}

# arg1: ZFS filesystem
# prints: nothing
# returns: 0 if kernels were found, 1 otherwise

find_be_kernels() {
  local fs mnt
  local kpath ipath kernel_records

  fs="${1}"
  if [ -z "${fs}" ]; then
    zerror "fs is undefined"
    return 1
  fi
  zdebug "fs set to ${fs}"

  # Try to mount, just skip the list otherwise
  if ! mnt="$( mount_zfs "${fs}" 2>&1 )"; then
    zerror "unable to mount ${fs}"
    return 1
  fi

  # Make sure the kernel list starts fresh
  kernel_records="${mnt%/*}/kernels"
  : > "${kernel_records}"

  # Look for kernels and matching initramfs, sorted in version order
  while read -r kpath; do
    # Strip mount point from path
    [ -n "${kpath}" ] || continue;
    kpath="${kpath#"${mnt}"}"
    kpath="/${kpath#/}"

    if ipath="$( find_be_initramfs "${mnt}${kpath}" )"; then
      zdebug "found kernel: ${mnt}${kpath}, initramfs ${mnt}${ipath}"
      ipath="${ipath#"${mnt}"}"
      ipath="/${ipath#/}"
      printf "%s\t%s\t%s\n" "${fs}" "${kpath}" "${ipath}" >> "${kernel_records}"
    else
      zdebug "kernel ${mnt}${kpath} has no initramfs"
    fi
  done <<<"$(
    for k in "${mnt}/boot"/{{vm,}linu{x,z},kernel}{,-*}; do
      [ -e "${k}" ] && echo "${k}"
    done | sort -V
  )"

  # No further need for the mount
  umount "${mnt}"

  # Search was successful if at least one kernel can be selected
  [ -s "${kernel_records}" ] && select_kernel "${fs}" >/dev/null && return 0

  # Remove an invalid kernel record if the search failed
  zerror "failed to find kernels on ${fs}"
  rm -f "${kernel_records}"
  return 1
}

# arg1: ZFS filesystem
# prints: fs kernel initramfs
# returns: 0 if a kernel can be identified, 1 if not

select_kernel() {
  local zfsbe kernel_list specific_kernel kexec_args spec_kexec_args

  zfsbe="${1}"
  if [ -z "${zfsbe}" ]; then
    zerror "zfsbe is undefined"
    return 1
  fi
  zdebug "zfsbe set to ${zfsbe}"

  kernel_list="$( be_location "${zfsbe}" )/kernels"

  if [ ! -s "${kernel_list}" ]; then
    zerror "kernel list '${kernel_list}' missing or empty"
    return 1
  fi

  # By default, select the last kernel entry
  kexec_args="$( tail -1 "${kernel_list}" )"

  # If a specific kernel is listed, prefer it when possible
  specific_kernel="$( zfs get -H -o value org.zfsbootmenu:kernel "${zfsbe}" 2>/dev/null )"
  if [ "${specific_kernel}" != "-" ]; then
    zdebug "org.zfsbootmenu:kernel set to ${specific_kernel}"
    while read -r spec_kexec_args; do
      local fs kernel initramfs
      IFS=$'\t' read -r fs kernel initramfs <<<"${spec_kexec_args}"
      if [[ "${kernel}" =~ ${specific_kernel} ]]; then
        zdebug "matched ${kernel} to ${specific_kernel}"
        kexec_args="${spec_kexec_args}"
      fi
    done < "${kernel_list}"
  fi

  if [ -z "${kexec_args}" ]; then
    zerror "failed to identify kexec arguments for ${fs}"
    return 1
  fi

  zdebug "using kexec args: ${kexec_args}"
  echo "${kexec_args}"
}

# arg1: ZFS filesystem
# arg2: path for the mounted filesystem
# prints: discovered prefix for root= command-line argument

find_root_prefix() {
  local zfsbe_mnt zfsbe_fs prefix

  zfsbe_fs="${1}"
  if [ -z "${zfsbe_fs}" ]; then
    zerror "zfsbe_fs is undefined"
    return 1
  fi
  zdebug "zfsbe_fs set to ${zfsbe_fs}"

  zfsbe_mnt="${2}"
  if [ -z "${zfsbe_mnt}" ]; then
    zerror "zfsbe_mnt is undefined"
    return 1
  fi
  zdebug "zfsbe_mnt set to ${zfsbe_mnt}"

  # Grab the root prefix from a property if possible
  if prefix="$( zfs get -H -o value org.zfsbootmenu:rootprefix "${zfsbe_fs}" 2>/dev/null )"; then
    if [ "${prefix}" != "-" ]; then
      zdebug "using org.zfsbootmenu:rootprefix: ${prefix}"
      echo "${prefix}"
      return
    fi
  fi

  # Try looking at os-release in BE
  if [ -n "${zfsbe_mnt}" ]; then
    prefix=$(
      # OS type is in ID and ID_LIKE variables; /etc supersedes /usr/lib
      unset ID ID_LIKE
      for osrel in ${zfsbe_mnt}/{usr/lib,etc}/os-release; do
        if [ -r "${osrel}" ]; then
          # shellcheck disable=SC1090
          . "${osrel}" >/dev/null 2>&1
        fi
      done

      for ostype in $ID $ID_LIKE; do
        case "$ostype" in
          void|ubuntu|debian|devuan|chimera)
            echo "root=zfs:"
            break
            ;;
          arch|artix)
            echo "zfs="
            break
            ;;
          gentoo|alpine)
            echo "root=ZFS="
            break
            ;;
          *)
            ;;
        esac
      done
    )

    if [ -n "${prefix}" ]; then
      zdebug "using os-release: ${prefix}"
      echo "${prefix}"
      return;
    fi
  fi

  # Just return a default
  zdebug "using default"
  echo "root=zfs:"
}

# arg1: ZFS KCL cache to validate
# returns: 0 if cache is valid, 1 otherwise

validate_cmdline_cache() {
  local cf
  cf="${1}"

  # Cache is trivially invalid when it fails to exist!
  [ -r "${cf}" ] || return 1

  # Otherwise, only the noresume flag can invalidate
  [ -e "${BASE}/noresume" ] || return 0

  # Cache is still valid if it was written after noresume flag
  [ "${cf}" -nt "${BASE}/noresume" ] && return 0

  # By default, cache is invalid
  return 1
}

# arg1: ZFS filesystem
# prints: kernel command line arguments
# returns: nothing

load_be_cmdline() {
  local fs args spl_hostid kcl cache rems adds

  fs="${1}"
  if [ -z "${fs}" ]; then
    zerror "filesystem is undefined"
    return 1
  fi
  zdebug "fs set to ${fs}"

  cache="$( be_location "${fs}" )/cmdline"

  if [ -r "${BASE}/cmdline" ]; then
    # Always prefer a user-entered KCL
    zdebug "using ${BASE}/cmdline as command line for ${fs}"
    kcl_assemble < "${BASE}/cmdline"
    return
  elif validate_cmdline_cache "${cache}"; then
    # Otherwise, if the BE has a valid KCL cache, just assemble that
    zdebug "using cached KCL from ${cache} as command line for ${fs}"
    kcl_assemble < "${cache}"
    return
  fi

  # root= is ALWAYS controlled by ZFSBootMenu
  rems=( "root" )

  # Nothing is added by default
  adds=()

  # In all other cases, build and attempt to cache the KCL
  args="$(read_kcl_prop "${fs}" | kcl_tokenize && exit "${PIPESTATUS[0]}" )" || args=""
  # Use a very basic default KCL if none is specified
  [ -n "${args}" ] || args="quiet loglevel=4"

  if [ -e "${BASE}/noresume" ]; then
    # Drop resume= arguments and append a noresume
    zdebug "${BASE}/noresume set, expunging from ${fs}"
    rems+=( "resume" )
    adds+=( "noresume" )
  fi

  # shellcheck disable=SC2154
  if [ "${zbm_set_hostid:-0}" -eq 1 ] && spl_hostid="$( get_spl_hostid )"; then
    zdebug "overriding spl_hostid and spl.spl_hostid for ${fs}"

    if [ "${spl_hostid}" = "0x00000000" ]; then
      # spl.spl_hostid=0 is a no-op; imports fall back to /etc/hostid. Dracut
      # writes spl_hostid to /etc/hostid to yield expected results. Others
      # (initramfs-tools, mkinitcpio) ignore this, but there isn't much else
      # that can be done with those systems.
      spl_hostid="spl_hostid=00000000"
    else
      # Using spl.spl_hostid sets a module parameter which takes precedence
      # over any /etc/hostid and should produce expected behavior everywhere
      spl_hostid="spl.spl_hostid=${spl_hostid}"
    fi

    rems+=( "spl_hostid" "spl.spl_hostid" )
    adds+=( "${spl_hostid}" )
  fi

  # Write the cached command line, if possible
  zdebug "caching KCL for ${fs} at ${cache}"
  args="$( kcl_suppress "${rems[@]}" <<< "${args}" | kcl_append "${adds[@]}" )"
  printf "%s\n" "${args}" > "${cache}"

  kcl="$( kcl_assemble <<< "${args}" )"
  zdebug "assembled commandline: '${kcl}'"
  echo "${kcl}"
}

# arg1: pool name, empty to import all
# prints: nothing
# returns: 0 on success, 1 on failure

# Accepted environment variables
# import_policy=force: enable force importing of a pool
# read_write=1: import read-write, defaults to read-only
# rewind_to_checkpoint=1: enable --rewind-to-checkpoint

import_pool() {
  local pool import_args import_output

  pool="${1}"

  #shellcheck disable=SC2154
  if [ -n "${pool}" ]; then
    zdebug "pool set to ${pool}"
  elif [ -n "${rewind_to_checkpoint}" ]; then
    zerror "rewind only works on a specific pool"
    return 1
  else
    zdebug "attempting to import all pools"
    pool="-a"
  fi

  # Import /never/ mounts filesystems
  import_args=( "-N" )

  # shellcheck disable=SC2154
  if [ "${import_policy}" == "force" ]; then
    import_args+=( "-f" )
    zdebug "import_policy set: ${import_policy}"
  fi

  # shellcheck disable=SC2154
  if [ -n "${read_write}" ]; then
    import_args+=( "-o" "readonly=off" )
    zdebug "read_write set: ${read_write}"
  else
    import_args+=( "-o" "readonly=on" )
    zdebug "read_write unset"
  fi

  # shellcheck disable=SC2154
  if [ -n "${rewind_to_checkpoint}" ]; then
    import_args+=( "--rewind-to-checkpoint" )
    zdebug "rewind_to_checkpoint set: ${rewind_to_checkpoint}"
  fi

  zdebug "zpool import arguments: ${import_args[*]} ${pool}"

  import_output="$(
    zpool import "${import_args[@]}" "${pool}" 2>&1
  )"
  ret=$?

  if [ "$ret" -eq 0 ]; then
    zdebug "successful pool import"
  else
    spl_hostid="$( get_spl_hostid )"
    zdebug "import process failed with code ${ret}, apparent hostid ${spl_hostid:-unknown}"
    zdebug "${import_output}"
  fi

  return "${ret}"
}

# arg1: pool name
# prints: nothing
# returns: 0 on success, 1 on failure

export_pool() {
  local pool

  pool="${1}"
  if [ -z "${pool}" ]; then
    zerror "pool is undefined"
    return 1
  fi
  zdebug "pool set to ${pool}"

  # shellcheck disable=SC2034
  status="$( zpool export "${pool}" )"
  ret=$?

  zdebug "${pool} export process return: ${ret}"

  return "${ret}"
}

# arg1: pool name
# prints: nothing
# returns: 0 on success, 1 on failure

rewind_checkpoint() {
  local pool checkpoint decision
  pool="${1}"
  if [ -z "${pool}" ]; then
    zerror "pool is undefined"
    return 1
  fi
  zdebug "pool set to ${pool}"

  while read -r line; do
    case "$line" in
      checkpoint*)
        checkpoint="${line#checkpoint: }"
        ;;
    esac
  done <<<"$( zpool status "${pool}" 2>/dev/null )"

  [ -z "${checkpoint}" ] && return 1
  tput clear
  tput cnorm
  tput cup 0 0

  cat <<-EOF
	WARNING!!!

	Rewinding a checkpoint for the ZFS pool

		$( colorize "red" "${pool}" )

	can not be undone!

	If you choose to proceed, the pool will revert
	to the state recorded when the checkpoint was taken.

	Type $( colorize "red" "REWIND" ) to proceed with the checkpoint rewind.

	Type any other text, or just press enter, to abort.

	Proceed $( colorize "red" "[No]" ) ?
	EOF

  decision="$( /libexec/zfsbootmenu-input )"

  [ "${decision}" = "REWIND" ] || return 1

  rewind_to_checkpoint=yes force_export=yes set_rw_pool "${pool}"
  return $?
}

# prints: nothing
# returns: 0 if suspend device found, 1 otherwise

has_resume_device() {
  # These partition types come from the dracut 95resume module
  for stype in suspend swsuspend swsupend; do
    if blkid -t TYPE="${stype}" >/dev/null 2>&1; then
      zdebug "resume device: ${stype}"
      return 0
    fi
  done

  return 1
}

# getopts arguments:
# -d  prompt countdown/delay; non-positive values will wait forever
# -p  prompt with countdown timer (use %0.Xd as a placeholder for time)
# -m+ message to be printed above the prompt, usable multiple times
# -r  message to be prefixed with [RETURN] (accept)
# -e  message to be prefixed with [ESCAPE] (reject)
#
# -m, -r, -e are printed in the order they are passed to the function

timed_prompt() {
  local prompt delay message infinite opt OPTIND

  infinite=
  while getopts "d:p:m:r:e:" opt; do
    case "${opt}" in
      d)
        delay="${OPTARG:-0}"
        if [ "${delay}" -gt 0 ] >/dev/null 2>&1; then
          :
        elif [ "${delay}" -le 0 ] >/dev/null 2>&1; then
          delay="30"
          infinite="yes"
        else
          zdebug "delay argument for timed_prompt is not numeric"
          return 0
        fi
        ;;
      p)
        prompt="${OPTARG}"
        ;;
      m)
        message+=( "${OPTARG}" )
        ;;
      r)
        message+=( "$( colorize green "[RETURN]" ) ${OPTARG}" )
        ;;
      e)
        message+=( "$( colorize red "[ESCAPE]" ) ${OPTARG}" )
        ;;
      *)
        ;;
    esac
  done

  [ "${delay:-0}" -gt 0 ] >/dev/null 2>&1 || delay="30"

  if [ -z "${prompt}" ]; then
    prompt="Press $( colorize green "[RETURN]") to continue"
    [ -z "${infinite}" ] && prompt+=" or wait $( colorize yellow "%0.${#delay}d" ) seconds"
  fi

  # Add a blank line between any messages and the prompt
  message+=( "" )

  local x y lines

  lines="${#message[@]}"

  [ "${lines}" -gt 0 ] || return 1

  tput civis
  HEIGHT=$( tput lines )
  WIDTH=$( tput cols )
  tput clear

  x=$(( ( (HEIGHT - 0 ) / 2 ) - lines ))
  [ "${x}" -lt 0 ] && x=0

  for line in "${message[@]}"; do
    short="$( decolorize "${line}" )"
    y=$(( (WIDTH - ${#short}) / 2 ))
    [ "${y}" -lt 0 ] && y=0
    tput cup $x $y
    echo -n -e "${line}"
    x=$(( x + 1 ))
    shift
  done

  local readargs
  readargs=( -s -N 1 )
  [ -z "${infinite}" ] && readargs+=( -t 1 )

  for (( i=delay; i>0; i-- )); do
    # shellcheck disable=SC2059
    mes="$( printf "${prompt}" "${i}" )"
    short="$( decolorize "${mes}" )"
    y=$(( (WIDTH - ${#short}) / 2 ))
    [ "${y}" -lt 0 ] && y=0
    tput cup $x $y
    echo -ne "${mes}"

    # shellcheck disable=SC2162
    IFS='' read "${readargs[@]}" key
    # escape key
    if [ "$key" = $'\e' ]; then
      return 1
    # enter key
    elif [ "$key" = $'\x0a' ]; then
      return 0
    fi

    # If delay is infinite, don't let it tick down
    [ -n "${infinite}" ] && i=$(( i + 1 ))
  done

  return 0
}

# arg1: pool name
# prints: warning message
# returns: 0 on success, 1 on failure

resume_prompt() {
  local pool decision

  pool="${1}"
  if [ -z "${pool}" ]; then
    zerror "pool is undefined"
    return 1
  fi
  zdebug "pool set to ${pool}"

  # Try to avoid importing writable when a resume device is found
  if has_resume_device; then
    # If NORESUME was already provided, never allow it to be taken back
    [ -r "${BASE}/noresume" ] && return 0

    # Make sure the warning is prominent
    tput clear
    tput cnorm
    tput cup 0 0

    cat <<-EOF
	WARNING!!!

	This system appears to have an active suspend partition.

	The action you are requesting requires the ZFS pool

	    $( colorize "red" "${pool}" )

	be imported read-write. Importing read-write and then resuming
	from an active suspend partition may DESTROY YOUR POOL.

	If you choose to proceed, ZFSBootMenu can attempt to remove any
	"resume=" arguments from your kernel command line and append a
	"noresume" argument to prevent your system from attempting to
	restore from the active suspend partition.

	Type $( colorize "green" "NORESUME" ) to proceed with the import, allowing ZFSBootMenu
	to add a "noresume" argument to your kernel command line.

	Type $( colorize "red" "DANGEROUS" ) to proceed with the import without allowing
	ZFSBootMenu to modify your kernel command line. Make sure to
	add the "noresume" argument yourself if necessary.

	Type any other text, or just press enter, to abort.

	Proceed $( colorize "red" "[No]" ) ?
	EOF

    decision="$( /libexec/zfsbootmenu-input )"

    if [ "${decision}" = "DANGEROUS" ]; then
      return 0
    elif [ "${decision}" = "NORESUME" ]; then
      : > "${BASE}/noresume"
      return 0
    else
      return 1
    fi
  fi

  return 0
}

# arg1: filesystem name
# prints: nothing
# returns: 0 when filesystem is snapshot, 1 otherwise

is_snapshot() {
  local snapshot

  snapshot="${1}"
  if [ -z "${snapshot}" ]; then
    zerror "snapshot is undefined"
    return 1
  fi

  if [[ "${snapshot}" =~ @ ]]; then
    return 0
  else
    return 1
  fi
}

# arg1: pool name
# prints: nothing
# returns: 0 when pool is writable, 1 otherwise

is_writable() {
  local pool roflag

  pool="${1}"
  if [ -z "${pool}" ]; then
    zerror "pool is undefined"
    return 1
  fi
  zdebug "pool set to ${pool}"

  # Pool is not writable if the property can't be read
  roflag="$( zpool get -H -o value readonly "${pool}" 2>/dev/null )" || return 1
  zdebug "${pool} readonly property: ${roflag}"

  if [ "${roflag}" = "off" ]; then
    return 0
  fi

  # Otherwise, pool is not writable
  return 1
}

# arg1: pool name
# prints: nothing
# returns: 0 on success, 1 on failure

set_rw_pool() {
  local pool ret

  pool="${1}"
  if [ -z "${pool}" ]; then
    zerror "pool is undefined"
    return 1
  fi
  zdebug "pool set to ${pool}"

  if [ -w /sys/module/zfs/parameters/zfs_bclone_enabled ] ; then
    zdebug "disabling block cloning on writeable pools"
    echo 0 > /sys/module/zfs/parameters/zfs_bclone_enabled
  fi

  if [ -w /sys/module/zfs/parameters/zfs_dmu_offset_next_sync ] ; then
    zdebug "disabling zfs_dmu_offset_next_sync on writeable pools"
    echo 0 > /sys/module/zfs/parameters/zfs_dmu_offset_next_sync
  fi

  # If force_export is set, skip evaluating if the pool is already read-write
  # shellcheck disable=SC2154
  [ -n "${force_export}" ] || ! is_writable "${pool}" || return 0

  zdebug "${pool} is not already writable"

  if grep -q "${pool}" "${BASE}/degraded" >/dev/null 2>&1; then
    zdebug "prohibited: ${BASE}/degraded is set"
    timed_prompt -d 10 \
      -m "$( colorize red "Operation prohibited" )" \
      -m "Pool '$( colorize cyan "${pool}" )' cannot be imported $( colorize red "read-write" )"
    return 1
  fi

  resume_prompt "${pool}" || return 1

  if export_pool "${pool}" ; then
    read_write=yes import_pool "${pool}"
    ret=$?

    zdebug "import_pool: ${ret}"

    return ${ret}
  fi

  return 1
}

# arg1: pool name
# prints: nothing
# returns: 0 on success, 1 on failure

set_ro_pool() {
  local pool ret

  pool="${1}"
  if [ -z "${pool}" ]; then
    zerror "pool is undefined"
    return 1
  fi
  zdebug "pool set to ${pool}"

  if export_pool "${pool}" ; then
    read_write='' import_pool "${pool}"
    ret=$?

    zdebug "import_pool: ${ret}"

    return ${ret}
  fi

  return 1
}


# arg1: ZFS filesystem or snapshot
# prints: name of encryption root, if present
# returns: 0 if system has an encryption root, 1 otherwise

be_has_encroot() {
  local fs pool encroot

  fs="${1%@*}"
  if [ -z "${fs}" ]; then
    zerror "fs is undefined"
    return 1
  fi
  zdebug "fs set to ${fs}"

  pool="${fs%%/*}"

  if [ "$( zpool list -H -o feature@encryption "${pool}" 2>/dev/null )" != "active" ]; then
    zdebug "feature@encryption not active on ${pool}"
    echo ""
    return 1
  fi

  if encroot="$( zfs get -H -o value encryptionroot "${fs}" 2>/dev/null )"; then
    zdebug "${fs} encryptionroot property: ${encroot}"
    if [ "${encroot}" != "-" ]; then
      echo "${encroot}"
      return 0
    fi
  fi

  echo ""
  return 1
}

# arg1: ZFS filesystem
# prints: name of encryption root, iff filesystem is locked
# returns: 0 if filesystem is locked, 1 otherwise

be_is_locked() {
  local fs keystatus encroot

  fs="${1}"
  if [ -z "${fs}" ]; then
    zerror "fs is undefined"
    return 1
  fi
  zdebug "fs set to ${fs}"

  if encroot="$( be_has_encroot "${fs}" )"; then
    zdebug "${encroot} discovered as encryption root for ${fs}"
    keystatus="$( zfs get -H -o value keystatus "${encroot}" 2>&1 )"
    zdebug "${encroot} keystatus: ${keystatus}"
    case "${keystatus}" in
      unavailable)
        echo "${encroot}"
        return 0;
        ;;
      *)
        ;;
    esac
  fi

  echo ""
  return 1
}

# arg1: BE key source
# prints: value of org.zfsbootmenu:keysource for BE, iff it is a valid filesystem
# returns: 0 iff the value is defined, not empty and is a valid filesystem

be_keysource() {
  local fs keysrc

  fs="${1}"
  if [ -z "${fs}" ]; then
    zerror "fs is undefined"
    return 1
  fi
  zdebug "fs set to ${fs}"

  if ! keysrc="$( zfs get -H -o value org.zfsbootmenu:keysource "${fs}" 2>/dev/null )"; then
    zwarn "failed to read org.zfsbootmenu:keysource on ${fs}"
    echo ""
    return 1
  fi

  if [ "${keysrc}" = "-" ] || [ -z "${keysrc}" ]; then
    echo ""
    return 1;
  fi

  if ! zfs list -o name -H "${keysrc}" >/dev/null 2>&1; then
    zdebug "keysource ${keysrc} for ${fs} is not a filesystem"
    echo ""
    return 1;
  fi

  echo "${keysrc}"
  return 0
}

# arg1: ZFS filesystem
# arg2: key location
# prints: nothing
# returns: 0 iff a key was cached

cache_key() {
  local fs mnt ret mutex keycache
  local ksmount relkeyloc keypath keylocation keyfile keydir keysrc

  fs="${1}"
  if [ -z "${fs}" ]; then
    zerror "fs is undefined"
    return 1
  fi
  zdebug "fs set to ${fs}"

  keylocation="${2}"
  if [ -z "${keylocation}" ]; then
    zerror "keylocation is undefined"
    return 1
  fi
  zdebug "keylocation set to ${keylocation}"

  # Strip scheme if it exists
  keyfile="${keylocation#file://}"
  # Make file relative to root
  keyfile="${keyfile#/}"

  if [ "${keyfile}" = "${keylocation}" ] || [ -z "${keyfile}" ]; then
    # No change or no file => keylocation is not a file => nothing to cache
    return 1;
  fi

  # Make sure a key source is defined
  if ! keysrc="$( be_keysource "${fs}" )"; then
    zdebug "no key source found for $fs"
    return 1
  fi

  keycache="${BASE}/.keys/${keysrc}"
  mutex="${keycache}/.cachemutex.$$"

  if [ -e "${mutex}" ]; then
    # Attempting to load key source could lead to infinite recursion
    # Break the chain by only attempting to cache if not previously attempted
    zdebug "will not repeat cache attempt for ${keysrc}:${keyfile}"
    return 1
  fi

  # Populate the cache if possible
  zdebug "attempting to cache ${keysrc}:${keyfile}"

  if ! mkdir -p "${keycache}"; then
    return 1
  fi

  # Make sure to touch the cache mutex
  : > "${mutex}"
  if [ ! -e "${mutex}" ]; then
    zerror "failed to acquire mutex ${mutex}"
    return 1
  fi

  if ! load_key "${keysrc}"; then
    # Key failed to load, clean up mutex
    zwarn "failed to load key for ${keysrc}"
    rm -f "${mutex}"
    return 1
  fi

  if ! mnt="$( mount_zfs "${keysrc}" )"; then
    # Mount failed (this shouldn't happen), clean up mutex
    zerror "failed to mount ${keysrc}"
    rm -f "${mutex}"
    return 1
  fi

  relkeyloc=""
  if ksmount="$(zfs get -o value -H mountpoint "${keysrc}" 2>/dev/null )"; then
    case "${ksmount}" in
      none|legacy)
        zdebug "no discernable mountpoint for ${keysrc}, using only absolute key path"
        ;;
      /*)
        # For absolute mountpoints, strip the root
        ksmount="${ksmount#/}"

        # Key location relative to expected mountpoint of keysource
        relkeyloc="${keyfile#"${ksmount}"}"
        relkeyloc="${relkeyloc#/}"

        zdebug "${keysrc} mounts at ${ksmount}, trying relative path ${relkeyloc}"

        if [ "${relkeyloc}" = "${keyfile}" ]; then
          # If location isn't different, there is no relative location
          relkeyloc=""
          zdebug "relative path ${relkeyloc} matches absolute, ignoring"
        fi
        ;;
      *)
        zwarn "ignoring nonsense mountpoint ${ksmount} on filesystem ${keysrc}"
        ;;
    esac
  fi

  if [ -n "${relkeyloc}" ] && [ -e "${mnt}/${relkeyloc}" ]; then
    # Prefer a path relative to the expected mountpoint of the keysource
    keypath="${mnt}/${relkeyloc}"
    zdebug "caching key from mount-relative path ${keysrc}:${relkeyloc}"
  elif [ -e "${mnt}/${keyfile}" ]; then
    keypath="${mnt}/${keyfile}"
    zdebug "caching key from absolute path ${keysrc}:${keyfile}"
  else
    keypath=""
    zdebug "no key found at ${keysrc}:${keyfile}"
  fi

  ret=1
  if [ -n "${keypath}" ]; then
    # Cache target is always full path below fs cache root
    keydir="${keyfile%/*}"
    if [ "${keydir}" != "${keyfile}" ] && [ -n "${keydir}" ]; then
      mkdir -p "${keycache}/${keydir}"
    fi

    if cp "${keypath}" "${keycache}/${keyfile}"; then
      zdebug "copied key ${keypath} to ${keycache}/${keyfile}"
      ret=0
    else
      zerror "failed to copy ${keypath} to ${keycache}/${keyfile}"
    fi
  fi

  # Clean up mount and mutex
  umount "${mnt}"
  rm -f "${mutex}"
  return $ret
}

# arg1: ZFS filesystem
# prints: nothing
# returns: 0 on success, 1 on failure
#
# NOTE: this function should *not* be called from a subshell

load_key() {
  local fs encroot key keypath keyformat keylocation keysource hook_envs

  fs="${1}"
  if [ -z "${fs}" ]; then
    zerror "fs is undefined"
    return 1
  fi
  zdebug "fs set to ${fs}"

  # Nothing to do if filesystem is not locked
  if ! encroot="$( be_is_locked "${fs}" )" || [ -z "${encroot}" ]; then
    return 0
  fi

  # Run load-key hooks, if they exist
  hook_envs=( ZBM_LOCKED_FS="${fs}" ZBM_ENCRYPTION_ROOT="${encroot}" )
  if env "${hook_envs[@]}" /libexec/zfsbootmenu-run-hooks "load-key.d"; then
    # If hooks ran, check if the filesystem has been unlocked
    if ! be_is_locked "${fs}" >/dev/null; then
      zdebug "fs ${fs} unlocked by user hooks"
      return 0
    fi
  fi

  # Default to 0 when unset
  [ -n "${CLEAR_SCREEN}" ] || CLEAR_SCREEN=0
  [ -n "${NO_CACHE}" ] || NO_CACHE=0

  # If something goes wrong discovering key location, just prompt
  if ! keylocation="$( zfs get -H -o value keylocation "${encroot}" 2>/dev/null )"; then
    zdebug "failed to read keylocation on ${encroot}"
    keylocation="prompt"
  fi

  if [ "${keylocation}" = "prompt" ]; then
    zdebug "prompting for passphrase for ${encroot}"
    if [ "${CLEAR_SCREEN}" -eq 1 ] ; then
      tput clear
      tput cup 0 0
    fi

    zfs load-key -L prompt "${encroot}"
    return $?
  fi

  # Strip file path, relative to root
  key="${keylocation#file://}"
  key="${key#/}"

  if [ -e "/${key}" ]; then
    # Prefer the actual path to the key file
    keypath="/${key}"
  elif keysource="$( be_keysource "${fs}" )" && ! [ "${NO_CACHE}" -eq 1 ]; then
    # Otherwise, try to pre-seed a cache location
    # Don't care if this succeeds because it may already be cached
    cache_key "${fs}" "${keylocation}"
    # Cache loading may have unlocked this BE, don't try again
    if ! be_is_locked "${fs}" >/dev/null 2>&1; then
      zdebug "cache attempt has unlocked ${encroot}"
      return 0
    fi

    # If the cached key exists, prefer it
    if [ -e "${BASE}/.keys/${keysource}/${key}" ]; then
      keypath="${BASE}/.keys/${keysource}/${key}"
      zdebug "cached key path for $fs is ${keypath}"
    fi
  fi

  # Load a key from a file, if possible and necessary
  if [ -e "${keypath}" ] && be_is_locked "${fs}" >/dev/null 2>&1; then
    if zfs load-key -L "file://${keypath}" "${encroot}"; then
      zdebug "unlocked ${encroot} from key at ${keypath}"
      return 0
    fi
  fi

  # Otherwise, try to prompt for "passphrase" keys
  keyformat="$( zfs get -H -o value keyformat "${encroot}" 2>/dev/null )" || keyformat=""
  if [ "${keyformat}" != "passphrase" ]; then
    zdebug "unable to load key with format ${keyformat} for ${encroot}"
    return 1
  fi

  if [ "${CLEAR_SCREEN}" -eq 1 ] ; then
    tput clear
    tput cup 0 0
  fi

  zdebug "prompting for passphrase for ${encroot}"
  zfs load-key -L prompt "${encroot}"
  return $?
}

# arg1: ZFS filesystem
# prints: The base path to this filesystem for use by ZFSBootMenu functions, with out a trailing /
# returns: nothing

be_location() {
  local fs beloc
  fs="${1}"
  if [ -z "${fs}" ]; then
    zerror "fs is undefined"
    return 1
  fi
  zdebug "fs set to ${fs}"

  local beloc="${BASE}/environments/${fs}"
  mkdir -p "${beloc}"
  echo "${beloc}"
}

# arg1: ZFS filesystem
# prints: nothing
# returns: nothing

zfs_chroot() {
  local fs

  fs="${1}"
  if [ -z "${fs}" ]; then
    zerror "fs is undefined"
    return 1
  fi
  zdebug "fs set to ${fs}"

  tput clear
  tput cnorm

  zdebug "chroot environment: ${fs}"
  /bin/bash -c "zfs-chroot ${fs}"
}


# arg1: message
# prints: nothing
# returns: nothing

emergency_shell() {
  local skip mp fs

  tput clear
  tput cnorm
  stty echo

  cat <<-EOF
	$( colorize green "emergency shell")${1:+: $1}

	type '$(colorize red "help")' for online documentation
	type '$( colorize red "exit")' to return to ZFSBootMenu

	EOF

  if [ -f "${BASE}/have_errors" ]; then
    print_kmsg_logs "err"
    echo
    rm "${BASE}/have_errors"
  fi

  command -v efibootmgr >/dev/null 2>&1 && mount_efivarfs "rw" 

  # -i (interactive) mode will source $HOME/.bashrc
  ( trap - SIGINT; exec /bin/bash -i )

  # shellcheck disable=SC2034
  while read -r skip mp fs skip ; do
    if [ "${fs}" == "zfs" ]; then
      umount "${mp}"
      zdebug "unmounting: ${mp}"
    fi
  done < /proc/self/mounts

  # always remount as read-only
  mount_efivarfs
}

# prints: zpool list and zfs property list
# returns: nothing

zreport() {
  local hook

  colorize white "System Report\n\n"

  (
    VERSION="unknown"
    PRETTY_NAME="ZFSBootMenu"
    UNAME="$( uname -srm )"

    # shellcheck disable=SC1091
    [ -f /etc/zbm-release ] && source /etc/zbm-release

    if [[ "${VERSION}" =~ dev$ ]]; then
      VERSION="$( colorize red "${VERSION}" )"
    else
      VERSION="$( colorize green "${VERSION}" )"
    fi

    if [[ "${PRETTY_NAME}" == "ZFSBootMenu" ]]; then
      PRETTY_NAME="$( colorize orange ZFS )$( colorize lightgray BootMenu )"
    fi

    echo -e "${PRETTY_NAME} ${VERSION} (${UNAME})"
  )

  colorize orange "\n>> ZFSBootMenu commandline\n"
  get_zbm_kcl | kcl_assemble ; echo

  colorize orange "\n>> Enabled hooks\n"
  for hook in /libexec/hooks/*.d/*; do
    [ -x "${hook}" ] && echo "* $( colorize green "${hook}")"
  done

  colorize orange "\n>> Disabled hooks\n"
  for hook in /libexec/hooks/*.d/*; do
    [ -f "${hook}" ] || continue
    [ -x "${hook}" ] && continue
    echo "* $( colorize red "${hook}")"
  done

  colorize orange "\n>> ZFS/SPL module information\n"
  echo "$( modinfo -F filename spl ): $( modinfo -F version spl )"
  echo "$( modinfo -F filename zfs ): $( modinfo -F version zfs )"

  colorize orange "\n>> ZFS version\n"
  zfs version

  colorize orange "\n>> Imported zpools\n"
  zpool list

  colorize orange "\n>> ZFS datasets\n"
  zfs list -o name,mountpoint,canmount,encroot,keystatus,keylocation,org.zfsbootmenu:keysource
}

# arg1: hook root spec, as <device>//<path>
# prints: nothing
# returns: 0 iff device and path are valid

import_zbm_hooks() {
  local hook_root hook_fs hook_path hook_mount hdir hsrc hfile

  hook_root="${1}"
  if [ -z "${hook_root}" ]; then
    zerror "hook root is not defined"
    return 1
  fi

  hook_fs="${hook_root%//*}"
  if [ -z "${hook_fs}" ] || [ "${hook_fs}" = "${hook_root}" ]; then
    zerror "unable to find hook device: '${hook_root}' is malformed"
    return 1
  fi

  hook_path="${hook_root##*//}"
  if [ -z "${hook_path}" ] || [ "${hook_path}" = "${hook_root}" ]; then
    zerror "unable to find hook path: '${hook_root}' is malformed"
    return 1
  fi

  hook_mount="${BASE}/.external_hooks"
  mkdir -p "${hook_mount}"
  if ! mount -r "${hook_fs}" "${hook_mount}"; then
    zerror "failed to mount hook filesystem ${hook_fs}"
    return 1
  fi

  for hsrc in "${hook_mount}/${hook_path}"/*; do
    [ -d "${hsrc}" ] || continue
    hdir="${hsrc##*/}"

    if ! mkdir -p "/libexec/hooks/${hdir}"; then
      zwarn "failed to create hook directory ${hdir}"
      continue;
    fi

    for hfile in "${hsrc}"/*; do
      [ -f "${hfile}" ] || continue
      if ! cp "${hfile}" "/libexec/hooks/${hdir}" >/dev/null 2>&1; then
        zwarn "failed to copy user hook ${hfile}"
      fi
    done
  done

  umount "${hook_mount}"

  return 0
}

# arg1: directory path
# prints: nothing
# returns: 0 if the directory is a mountpoint, 1 if directory is not a mountpoint

is_mountpoint() {
  local mount_path dev path opts

  if command -v mountpoint >/dev/null 2>&1; then
    mountpoint -q "${1}"
    return
  fi

  if ! mount_path="$(readlink -f "${1}")"; then
    zerror "parent of ${1} does not exist"
    return 1
  fi

  if [ ! -r /proc/self/mounts ]; then
    zerror "unable to read mount database"
    return 1
  fi

  # shellcheck disable=SC2034
  while read -r dev path opts; do
    path="$(readlink -f "${path}")" || continue
    [ "${path}" = "${mount_path}" ] && return 0
  done < /proc/self/mounts

  return 1
}

# arg1: device or dataset name
# prints: mountpoint if mounted 
# returns: 0 if the device is mounted, 1 if not

is_mounted() {
  local mount_path dev path opts

  mount_dev="${1}"

  if [ -z "${mount_dev}" ]; then
    zerror "mount_dev undefined"
    return 1
  fi

  if [ ! -r /proc/self/mounts ]; then
    zerror "unable to read mount database"
    return 1
  fi

  # shellcheck disable=SC2034
  while read -r dev path opts; do
    if [ "${dev}" = "${mount_dev}" ]; then
      echo "${path}"
      return 0
    fi
  done < /proc/self/mounts

  return 1
}

# args: none
# prints: nothing
# returns: 0 if EFI is detected, 1 if not

is_efi_system() {
  [ -d /sys/firmware/efi ] && return 0
  return 1
}

# arg1: 'ro' or 'rw' to mount or remount efivarfs in that desired mode
# arg2: optional mountpoint
# prints: nothing
# returns: 0 on success, 1 on failure, 2 if unsupported

mount_efivarfs() {
  local efivar_state efivar_location

  efivar_state="${1:-ro}"
  efivar_location="${2:-/sys/firmware/efi/efivars}"

  if ! is_efi_system ; then
    zdebug "efivarfs unsupported"
    return 2
  elif is_mountpoint "${efivar_location}" >/dev/null 2>&1 ; then
    zdebug "remounting '${efivar_location}' '${efivar_state}'"
    # remounting is cheap enough that it's not worth detecting the current state
    mount -t efivarfs efivarfs "${efivar_location}" -o "remount,${efivar_state}"
  else
    zdebug "mounting '${efivar_location}' '${efivar_state}'"
    mount -t efivarfs efivarfs "${efivar_location}" -o "${efivar_state}"
  fi
}

# arg1: zfs dataset name
# returns: 0 if filesystem

is_zfs_filesystem() {
  local dataset

  dataset="${1}"

  if [ -z "${dataset}" ]; then
    zerror "dataset undefined"
    return 1
  fi

  zfs list -H -o name -t filesystem "${dataset}" >/dev/null 2>&1 && return 0

  return 1
}
