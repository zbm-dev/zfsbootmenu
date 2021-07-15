#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# ZFS boot menu functions

# arg1: log level
# arg2: log line
# prints: nothing
# returns: nothing

zlog() {
  local _script _func prefix offset join _WIDTH
  [ -z "${1}" ] && return
  [ -z "${2}" ] && return

  # Assume a default log severity of "warning" if not specified
  # shellcheck disable=SC2154
  [ "${1}" -le "${loglevel:=4}" ] || return

  # shellcheck disable=SC2086
  _script="$( basename -- $0 )"
  _func="${FUNCNAME[2]}"

  # Only add script/function tracing to debug messages
  if [ "${1}" -eq 7 ] && [ -n "${HAS_NOESCAPE}" ] ; then
    prefix="<${1}>ZBM:\033[0;33m${_script}[$$]\033[0;31m:${_func}()\033[0m"
  elif [ "${1}" -eq 7 ]; then
    prefix="<${1}>ZBM:${_script}[$$]:${_func}()"
  else
    prefix="<${1}>ZFSBootMenu"
  fi

  offset="${#prefix}"

  # account for the fzf gutter and kernel timestamp
  _WIDTH=$(( $( tput cols ) - ( offset - 15 ) ))

  join=': '
  while read -r line; do
    echo -e "${prefix}${join}${line}" > /dev/kmsg
    join='+   '
  done <<<"$( echo "${2}" | fold -s -w "${_WIDTH}" )"
}

# arg1: log line
# prints: nothing
# returns: nothing

zdebug() {
  zlog 7 "$@"
}

zinfo() {
  zlog 6 "$@"
}

zwarn() {
  : > "${BASE}/have_warnings"
  zlog 4 "$@"
}

zerror() {
  : > "${BASE}/have_errors"
  zlog 3 "$@"
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

# Accepted environment variables:
# WIDTH: pre-calculated screen width

center_string() {
  local _WIDTH
  if [ -z "${WIDTH}" ]; then
    if [ -z "${FZF_PREVIEW_COLUMNS}" ]; then
      _WIDTH="$( tput cols )"
    else
      _WIDTH="${FZF_PREVIEW_COLUMNS}"
    fi
  else
    _WIDTH="${WIDTH}"
  fi
  printf "%*s" $(( (${#1} + _WIDTH ) / 2)) "${1}"
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

  # shellcheck disable=SC2154
  if [ "${endian}" = "be" ]; then
    # Write in big-endian format
    zdebug "writing hostid ${hostid} to /etc/hostid (big-endian)"
    echo -ne "\\x${hostid:0:2}\\x${hostid:2:2}\\x${hostid:4:2}\\x${hostid:6:2}" > "/etc/hostid"
    ret=$?
  else
    zdebug "writing hostid ${hostid} to /etc/hostid (little-endian)"
    echo -ne "\\x${hostid:6:2}\\x${hostid:4:2}\\x${hostid:2:2}\\x${hostid:0:2}" > "/etc/hostid"
    ret=$?
  fi

  if [ "${ret}" -eq 0 ] && [ -w "${splmod}" ]; then
    echo 0 > "${splmod}" || zwarn "failed to force spl.spl_hostid=0 for host ID matching"
  fi

  return ${ret}
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
    spl_hostid="$( od -tx4 -N4 -An /etc/hostid 2>/dev/null | tr -d '[:space:]' )"
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
  local importable pool state hostid single
  importable=()

  single="${1}"

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
          if [ "${state}" == "ONLINE" ] && [ -n "${pool}" ] && [ "${pool}" != "${root}" ]; then
            importable+=("${pool}")
            pool=""
          fi
          ;;
      esac
    done <<<"$( zpool import )"
  fi

  zdebug "importable pools: ${importable[*]}"

  for pool in "${importable[@]}"; do
    zdebug "trying to import: ${pool}"
    hostid="$( zpool import -o readonly=on -N "${pool}" 2>&1 | grep -E -o "hostid=[A-Za-z0-9]{1,8}")"

    if [ -n "${hostid}" ]; then
      hostid="$( printf "%08x" "0x${hostid##*=}" )"
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

      zwarn "imported ${pool} with assumed hostid ${hostid}"
      zwarn "set spl_hostid=${hostid} on ZBM KCL or regenerate with corrected /etc/hostid"

      echo "${pool};${hostid}"
      return 0
    fi
  done

  # no pools could be imported, we failed to match a hostid
  return 1
}

# args: none
# prints: nothing
# returns: 0 if at least one pool is available

check_for_pools() {
  while read -r _pool ; do
    [ -n "${_pool}" ] && return 0
  done <<<"$( zpool list -H -o name )"

  return 1
}

# arg1: ZFS filesystem name
# prints: mountpoint
# returns: 0 on success
#
# If the filesystem is locked, this method fails without attempting unlock

mount_zfs() {
  local fs rwo mnt ret pool is_snapshot

  fs="${1}"

  if [ -z "${fs}" ]; then
    zerror "fs is undefined"
    return 1
  fi

  if be_is_locked "${fs}" >/dev/null; then
    zdebug "${fs} is locked, returning"
    return 1
  fi

  mnt="${BASE}/${fs}/mnt"
  mkdir -p "${mnt}"

  # @ always denotes a snapshot
  if [[ "${fs}" =~ @ ]]; then
    is_snapshot=1
  fi

  # filesystems are readonly by default, but read-write mounts may be requested
  rwo="ro"
  # shellcheck disable=SC2154
  if [ -n "${allow_rw}" ]; then
    pool="${fs%%/*}"
    if is_writable "${pool}" && [ -z "${is_snapshot}" ]; then
      rwo="rw"
    else
      if [ -n "${is_snapshot}" ]; then
        zwarn "read-write mount of ${fs} forbidden, filesystem is a snapshot"
      else
        zwarn "read-write mount of ${fs} forbidden, pool ${pool} is not writable"
      fi
    fi
  fi

  # zfsutil is required for non-legacy mounts and omitted for legacy mounts or snapshots
  if [ "$(zfs get -H -o value mountpoint "${fs}")" = "legacy" ] || [ -n "${is_snapshot}" ]; then
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

# prints: first sort key
# returns: nothing

get_sort_key() {
  local sort_key
  sort_key="${zbm_sort%%;*}"
  zdebug "Using sorting key ${sort_key}"
  echo -n "${sort_key:-name}"
}

# arg1: value to substitute for empty first line (default: "enter")
# prints: concatenated lines of stdin, joined by commas

# shellcheck disable=SC2120
csv_cat() {
  local CSV empty line lineno
  empty=${1:-enter}

  lineno=0
  while read -r line; do
    if [ "$lineno" -eq 0 ]; then
      lineno=1
      if [ -z "$line" ]; then
        line="${empty}"
      else
        line="${line/ctrl-alt-/mod-}"
        line="${line/ctrl-/mod-}"
        line="${line/alt-/mod-}"
      fi
    fi
    CSV+=("${line}")
  done
  (IFS=',' ; printf '%s' "${CSV[*]}")
}

# arg1...argN: tokens to wrap
# prints: string, wrapped to width without breaking tokens
# returns: nothing

header_wrap() {
  local hardbreak tokens tok footer nlines allow_breaks maxcols curcols

  # Pick a wrap width if none was specified
  if [ -z "${wrap_width}" ]; then
    wrap_width="$(( $( tput cols 2>/dev/null ) - 4 ))"
    [ "${wrap_width}" -gt 0 ] || wrap_width=80
  fi

  # Pick a uniform field width
  if [ -z "${field_width}" ]; then
    field_width=0
    for tok in "$@"; do
      [ "${#tok}" -gt "${field_width}" ] && field_width="${#tok}"
    done
  fi

  # Determine maximum number of columns
  maxcols=0
  curcols=0
  for tok in "$@"; do
    if [ -z "${tok}" ]; then
      if [ "${curcols}" -gt "${maxcols}" ]; then
        maxcols="${curcols}"
      fi
      curcols=0
    else
      (( curcols=curcols+1 ))
    fi
  done

  # Honor hard breaks only if terminal is sufficiently tall and wide
  nlines="$( tput lines 2>/dev/null )" || nlines=0
  if [ "${nlines}" -ge 24 ] && [ "${wrap_width}" -ge "$(( maxcols * field_width ))" ]; then
    allow_breaks=1
  else
    allow_breaks=0
  fi

  # Processing is done line-by-line
  while [ $# -gt 0 ]; do
    hardbreak=0
    tokens=()

    # Process up to the first empty string, which is a hard break
    while [ $# -gt 0 ]; do
      # Pad fields if a uniform field width was assigned
      if [ "${field_width}" -gt 0 ] && [ -n "$1" ]; then
        tok="$( printf "%-${field_width}s" "$1" )"
        tok="${tok// /_}"
      else
        tok="${1// /_}"
      fi

      shift

      if [ -n "${tok}" ]; then
        # If breaks are disallowed, also suppress all-empty tokens
        [ "${allow_breaks}" -eq 1 ] || [ -n "${tok//_/}" ] || continue;
        tokens+=( "${tok}" )
      elif [ "${allow_breaks}" -eq 1 ]; then
        # Hard wrap on empty tokens only with sufficient space
        hardbreak=1
        break
      fi
    done

    # Print the header if there were tokens
    if [ "${#tokens[@]}" -gt 0 ]; then
      # Only try to wrap if the width is long enough
      if [ "${wrap_width}" -gt 0 ]; then
        [ "$(( field_width + 4 ))" -ge "${wrap_width}" ] && footer="${footer//_/ }"
        footer="$( echo -n -e "${tokens[@]}" | fold -s -w "${wrap_width}" )"
      else
        footer="$( echo -n -e "${tokens[@]}" )"
      fi

      # Add some color for emphasis
      footer="${footer//\[/\\033\[0;32m\[}"
      footer="${footer//\]/\]\\033\[0m}"

      echo -n -e "${footer//_/ }"
    fi

    # Add a hard break if an empty token was provided
    if [ "${hardbreak}" -ne 0 ]; then
      echo ""
    fi
  done
}

# arg1: Path to file with detected boot environments, 1 per line
# prints: key pressed, boot environment on successful selection
# returns: 0 on successful selection, 1 if Esc was pressed, 130 if BE list is missing

draw_be() {
  local env selected header expects

  env="${1}"
  if [ -z "${env}" ]; then
    zerror "environment file is undefined"
    return 130
  fi

  if [ ! -r "${env}" ] ; then
    zerror "environment file ${env} is missing"
    return 130
  fi

  zdebug "using environment file: ${env}"

  header="$( header_wrap \
    "[RETURN] boot" "[ESCAPE] refresh view" "[CTRL+P] pool status" "" \
    "[CTRL+D] set bootfs" "[CTRL+S] snapshots" "[CTRL+K] kernels" "" \
    "[CTRL+E] edit kcl" "[CTRL+I] interactive chroot" "[CTRL+R] recovery shell" "" \
    "[CTRL+L] view logs" " " "[CTRL+H] help" )"

  expects="--expect=alt-e,alt-k,alt-d,alt-s,alt-c,alt-r,alt-p,alt-w,alt-i,alt-o"

  if ! selected="$( ${FUZZYSEL} -0 --prompt "BE > " \
      ${expects} ${expects//alt-/ctrl-} ${expects//alt-/ctrl-alt-} \
      --header="${header}" --preview-window="up:${PREVIEW_HEIGHT}" \
      --preview="/libexec/zfsbootmenu-preview {} ${BOOTFS}" < "${env}" )"; then
    return 1
  fi

  # shellcheck disable=SC2119
  selected="$( csv_cat <<< "${selected}" )"
  echo "${selected}"
  zdebug "selected: ${selected}"

  return 0
}

# arg1: ZFS filesystem name
# prints: bootfs, kernel, initramfs
# returns: 130 on error, 0 otherwise

draw_kernel() {
  local benv selected header expects _kernels

  benv="${1}"
  if [ -z "${benv}" ]; then
    zerror "benv is undefined"
    return 130
  fi

  _kernels="${BASE}/${benv}/kernels"
  if [ ! -r "${_kernels}" ] ; then
    zerror "kernel file ${_kernels} missing"
    return 130
  fi

  zdebug "using kernels file: ${_kernels}"

  header="$( header_wrap "[RETURN] boot" "[ESCAPE] back" "" \
    "[CTRL+D] set default" "[CTRL+U] unset default" "" \
    "[CTRL+L] view logs" "[CTRL+H] help" )"

  expects="--expect=alt-d,alt-u"

  if ! selected="$( HELP_SECTION=kernel-management ${FUZZYSEL} \
     --prompt "${benv} > " --tac --with-nth=2 --header="${header}" \
      ${expects} ${expects//alt-/ctrl-} ${expects//alt-/ctrl-alt-} \
      --preview="/libexec/zfsbootmenu-preview ${benv} ${BOOTFS}"  \
      --preview-window="up:${PREVIEW_HEIGHT}" < "${_kernels}" )"; then
    return 1
  fi

  # shellcheck disable=SC2119
  selected="$( csv_cat <<< "${selected}" )"
  echo "${selected}"
  zdebug "selected: ${selected}"

  return 0
}

# arg1: ZFS filesystem name
# prints: selected snapshot
# returns: 130 on error, 0 otherwise

draw_snapshots() {
  local benv selected header expects sort_key

  benv="${1}"
  if [ -z "${benv}" ]; then
    zerror "benv is undefined"
    return 130
  fi
  zdebug "using boot environment: ${benv}"

  sort_key="$( get_sort_key )"

  header="$( header_wrap "[RETURN] duplicate" "[ESCAPE] back" "" \
    "[CTRL+X] clone and promote" "[CTRL+C] clone only" "" \
    "[CTRL+I] interactive chroot" "[CTRL+D] show diff" "" \
    "[CTRL+L] view logs" "[CTRL+H] help" )"

  expects="--expect=alt-x,alt-c,alt-i,alt-o"

  if ! selected="$( zfs list -t snapshot -H -o name "${benv}" -S "${sort_key}" |
      HELP_SECTION=snapshot-management ${FUZZYSEL} \
        --prompt "Snapshot > " --header="${header}" --tac \
        ${expects} ${expects//alt-/ctrl-} ${expects//alt-/ctrl-alt-} \
        --bind='alt-d:execute[ /libexec/zfunc draw_diff {} ]' \
        --bind='ctrl-d:execute[ /libexec/zfunc draw_diff {} ]' \
        --bind='ctrl-alt-d:execute[ /libexec/zfunc draw_diff {} ]' \
        --preview="/libexec/zfsbootmenu-preview ${benv} ${BOOTFS}" \
        --preview-window="up:${PREVIEW_HEIGHT}" )"; then
    return 1
  fi

  # shellcheck disable=SC2119
  selected="$( csv_cat <<< "${selected}" )"
  echo "${selected}"
  zdebug "selected: ${selected}"

  return 0
}

# arg1: ZFS snapshot
# arg2: ZFS filesystem
# prints: nothing
# returns: nothing

draw_diff() {
  local snapshot pool diff_target mnt
  local zfs_diff zfs_diff_PID

  snapshot="${1}"
  if [ -z "${snapshot}" ]; then
    zerror "snapshot is undefined"
    return 130
  fi
  zdebug "snapshot: ${snapshot}"

  pool="${snapshot%%/*}"
  zdebug "pool: ${pool}"

  if ! set_rw_pool "${pool}"; then
    zerror "unable to set ${pool} read/write"
    return
  fi

  diff_target="${snapshot%%@*}"
  zdebug "base filesystem: ${diff_target}"

  CLEAR_SCREEN=1 load_key "${diff_target}"

  if ! mnt="$( mount_zfs "${diff_target}" )" ; then
    zerror "unable to mount ${diff_target}"
    return
  fi

  coproc zfs_diff ( zfs diff -F -H "${snapshot}" "${diff_target}" )

  # Bash won't use an FD referenced in a variable on the left side of a pipe
  exec 3>&"${zfs_diff[0]}"

  # shellcheck disable=SC2154
  sed "s,${mnt},," <&3 | HELP_SECTION=diff-viewer ${FUZZYSEL} --prompt "${snapshot} > " \
    --preview="/libexec/zfsbootmenu-preview ${diff_target} ${BOOTFS}" \
    --preview-window="up:${PREVIEW_HEIGHT}"

  [ -n "${zfs_diff_PID}" ] && kill "${zfs_diff_PID}"

  umount "${mnt}"

  return
}

# arg1: nothing
# prints: selected pool
# returns: 130 on error, 0 otherwise

draw_pool_status() {
  local selected header psize

  # size the preview window to leave enough room for headers on the left
  psize="$(( $( tput cols ) - 34 ))"
  [ "${psize}" -le 0 ] && psize=10

  # Override uniform field width to force once item per line
  header="$( field_width=0 header_wrap "[ESCAPE] back" "" \
    "[CTRL+R] rewind checkpoint" "" "[CTRL+L] view logs" "" "[CTRL+H] help" )"

  if ! selected="$( zpool list -H -o name |
      HELP_SECTION=zpool-health ${FUZZYSEL} \
      --prompt "Pool > " --tac --expect=alt-r,ctrl-r,ctrl-alt-r \
      --preview-window="right:${psize}" \
      --preview="zpool status -v {}" --header="${header}" )"; then
    return 1
  fi

  # shellcheck disable=SC2119
  selected="$( csv_cat <<< "${selected}" )"
  echo "${selected}"
  zdebug "selected: ${selected}"

  return 0
}

# arg1: bootfs kernel initramfs
# prints: nothing
# returns: 1 on error, otherwise does not return

kexec_kernel() {
  local selected fs kernel initramfs tdhook output

  selected="${1}"
  if [ -z "${selected}" ]; then
    zerror "fs, kernel, initramfs undefined"
    return 130
  fi

  # zfs filesystem
  # kernel
  # initramfs
  IFS=' ' read -r fs kernel initramfs <<<"${selected}"

  zdebug "fs: ${fs}, kernel: ${kernel}, initramfs: ${initramfs}"

  CLEAR_SCREEN=1 load_key "${fs}"

  tput cnorm
  tput clear

  if ! mnt=$( mount_zfs "${fs}" ); then
    emergency_shell "unable to mount ${fs}"
    return 1
  fi

  cli_args="$( load_be_cmdline "${fs}" )"
  root_prefix="$( find_root_prefix "${fs}" "${mnt}" )"

  if ! output="$( kexec -l "${mnt}${kernel}" \
    --initrd="${mnt}${initramfs}" \
    --command-line="${root_prefix}${fs} ${cli_args}" 2>&1 )"
  then
    zerror "unable to load ${mnt}${kernel} and ${mnt}${initramfs} into memory"
    zerror "${output}"
    umount "${mnt}"
    color=red delay=10 timed_prompt "Unable to load kernel or initramfs into memory" \
      "${mnt}${kernel}" \
      "${mnt}${initramfs}"

    return 1
  else
    zdebug "loaded ${mnt}${kernel} and ${mnt}${initramfs} into memory"
    zdebug "kernel command line: '${root_prefix}${fs} ${cli_args}'"
    zdebug "${output}"
  fi

  umount "${mnt}"

  while read -r _pool; do
    if is_writable "${_pool}"; then
      zdebug "${_pool} is read/write, exporting"
      export_pool "${_pool}"
    fi
  done <<<"$( zpool list -H -o name )"

  # Run teardown hooks, if they exist
  if [ -d /libexec/teardown.d ]; then
    for tdhook in /libexec/teardown.d/*; do
      zinfo "Processing hook: ${tdhook}"
      [ -x "${tdhook}" ] && "${tdhook}"
    done
    unset tdhook
  fi

  if ! output="$( kexec -e -i 2>&1 )"; then
    zerror "kexec -e -i failed!"
    zerror "${output}"
    color=red delay=10 timed_prompt "kexec run of ${kernel} failed!"
    return 1
  fi
}

# arg1: snapshot name
# arg2: new BE name
# prints: nothing
# returns: 0 on success

duplicate_snapshot() {
  local selected target target_parent pool recv_args

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

  recv_args=( "-u" "-o" "canmount=noauto" "-o" "mountpoint=/" "${target}" )

  (
    trap 'exit 0' SIGINT
    if command -v mbuffer >/dev/null 2>&1; then
      # Buffer the exchange when possible
      zfs send -p -w "${selected}" | mbuffer | zfs recv "${recv_args[@]}"
    else
      zfs send -p -w "${selected}" | zfs recv "${recv_args[@]}"
    fi
  )
}

# arg1: snapshot name
# arg2: new BE name
# arg3: prevents promotion if equal to "nopromote"; otherwise ignored
# prints: nothing
# returns: 0 on success

clone_snapshot() {
  local selected target pool opts parent

  promote="${3}"

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

  promote="${3}"
  zdebug "promote: ${promote}"

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

  if [ "$promote" != "nopromote" ]; then
    # Promotion must succeed to continue
    zdebug "promoting ${target}"
    if ! zfs promote "${target}"; then
      zerror "unable to promote ${target}"
      return 1
    fi
  fi

  return 0
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

  # Strip /boot/ to list only the file
  kernel="${2#/boot/}"
  zdebug "kernel set to ${kernel}"

  # Make sure the pool is writable
  set_rw_pool "${pool}" || return 1
  CLEAR_SCREEN=1 load_key "${fs}"

  # Restore nonspecific default when no kernel specified
  if [ -z "$kernel" ]; then
    zfs inherit org.zfsbootmenu:kernel "${fs}" || return 1
  else
    zfs set org.zfsbootmenu:kernel="${kernel}" "${fs}" || return 1
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

# arg1: ZFS filesystem
# prints: nothing
# returns: 0 if kernels were found, 1 otherwise

find_be_kernels() {
  local fs mnt
  local kernel kernel_base labels version kernel_records
  local defaults def_kernel def_kernel_file

  fs="${1}"
  if [ -z "${fs}" ]; then
    zerror "fs is undefined"
    return 1
  fi
  zdebug "fs set to ${fs}"

  # Try to mount, just skip the list otherwise
  if ! mnt="$( mount_zfs "${fs}" )"; then
    zerror "unable to mount ${fs}"
    return 1
  fi

  # Check if /boot even exists in the environment
  if [ ! -d "${mnt}/boot" ]; then
    zdebug "${mnt}/boot not present"
    umount "${mnt}"
    return 1
  fi

  # Make sure the kernel list starts fresh
  kernel_records="${mnt/mnt/kernels}"
  : > "${kernel_records}"

  # shellcheck disable=SC2012,2086
  for kernel in $( ls \
      ${mnt}/boot/{{vm,}linu{x,z},kernel}{,-*} 2>/dev/null | sort -V ); do
    # Pull basename and validate
    kernel=$( basename "${kernel}" )
    [ -e "${mnt}/boot/${kernel}" ] || continue
    zdebug "found ${mnt}/boot/${kernel}"

    # Kernel "base" extends to first hyphen
    kernel_base="${kernel%%-*}"
    # Kernel "version" is everything after base and may be empty
    version="${kernel#${kernel_base}}"
    version="${version#-}"
    zdebug "kernel version: ${version}"

    # initramfs images can take many forms, look for a sensible one
    labels=( "$kernel" )
    if [ -n "$version" ]; then
      labels+=( "$version" )
    fi

    # Use a mess of loops instead better brace expansions to control priorities
    for ext in {.img,""}{"",.{gz,bz2,xz,lzma,lz4,lzo,zstd}}; do
      for pfx in initramfs initrd; do
        for lbl in "${labels[@]}"; do
          for i in "${pfx}-${lbl}${ext}" "${pfx}${ext}-${lbl}"; do
            if [ -e "${mnt}/boot/${i}" ]; then
              zdebug "matching ${i} to ${kernel}"
              echo "${fs} /boot/${kernel} /boot/${i}" >> "${kernel_records}"
              break 4
            fi
          done
        done
      done
    done

  done

  defaults="$( select_kernel "${fs}" )"
  # shellcheck disable=SC2034
  IFS=' ' read -r def_fs def_kernel def_initramfs <<<"${defaults}"

  def_kernel_file="${mnt/mnt/default_kernel}"

  # If no default kernel is found, there are no kernels; leave the BE
  # directory in the same state it would be in had no /boot existed
  if [ -z "${def_kernel}" ]; then
    umount "${mnt}"
    zdebug "no default kernel found for ${fs}"
    rm -f "${kernel_records}" "${def_kernel_file}"
    return 1
  fi
  zdebug "default kernel set to ${def_kernel}"

  basename "${def_kernel}" > "${def_kernel_file}"

  # Pre-load cmdline arguments, possibly from files on the mount
  preload_be_cmdline "${fs}" "${mnt}"

  umount "${mnt}"
  return 0
}

# arg1: ZFS filesystem
# prints: fs kernel initramfs
# returns: nothing

select_kernel() {
  local zfsbe specific_kernel kexec_args spec_kexec_args

  zfsbe="${1}"
  if [ -z "${zfsbe}" ]; then
    zerror "zfsbe is undefined"
    return 1
  fi
  zdebug "zfsbe set to ${zfsbe}"

  # By default, select the last kernel entry
  kexec_args="$( tail -1 "${BASE}/${zfsbe}/kernels" )"

  # If a specific kernel is listed, prefer it when possible
  specific_kernel="$( zfs get -H -o value org.zfsbootmenu:kernel "${zfsbe}" )"
  if [ "${specific_kernel}" != "-" ]; then
    zdebug "org.zfsbootmenu:kernel set to ${specific_kernel}"
    while read -r spec_kexec_args; do
      local fs kernel initramfs
      IFS=' ' read -r fs kernel initramfs <<<"${spec_kexec_args}"
      if [[ "${kernel}" =~ ${specific_kernel} ]]; then
        zdebug "matched ${kernel} to ${specific_kernel}"
        kexec_args="${spec_kexec_args}"
        break
      fi
    done <<<"$( tac "${BASE}/${zfsbe}/kernels" )"
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
  if prefix="$( zfs get -H -o value org.zfsbootmenu:rootprefix "${zfsbe_fs}" )"; then
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
          void|ubuntu|debian|devuan)
            echo "root=zfs:"
            break
            ;;
          arch)
            echo "zfs="
            break
            ;;
          gentoo)
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

# arg1: ZFS filesystem
# prints: value of org.zfsbootmenu:commandline, with %{parent} recursively expanded
# returns: 0 on success

read_kcl_prop() {
  local zfsbe args parfs par_args inherited

  zfsbe="${1}"
  if [ -z "${zfsbe}" ]; then
    zerror "zfsbe is undefined"
    return 1
  fi

  if ! args="$( zfs get -H -o value org.zfsbootmenu:commandline "${zfsbe}" )"; then
    zerror "unable to read org.zfsbootmenu:commandline on ${zfsbe}"
    return 1
  fi

  # KCL is empty, nothing to see
  if [ "${args}" = "-" ]; then
    zdebug "org.zfsbootmenu:commandline on ${zfsbe} has no value"
    echo ""
    return 0
  fi

  # KCL does not specify parent inheritance, just return the args
  if ! [[ "${args}" =~ "%{parent}" ]]; then
    zdebug "no parent reference in org.zfsbootmenu:commandline on ${zfsbe}"
    echo "${args}"
    return 0
  fi

  # Need to recursively expand "%{parent}"

  parfs="${zfsbe%/*}"
  if [ -z "${parfs}" ] || [ "${parfs}" = "${zfsbe}" ]; then
    # There is no parent, par_args is empty
    par_args=""
  else
    # Query the parent for kcl properties
    if ! par_args="$( read_kcl_prop "${parfs}" )"; then
      zwarn "failed to invoke read_kcl_prop on parent ${parfs}"
      par_args=""
    fi

    # When the KCL property is inherited, recursive expansion fully populates
    # the KCL at the level of the ancestor that actually defines the property.
    if inherited="$( zfs get -H -o source -s inherited org.zfsbootmenu:commandline "${zfsbe}" 2>/dev/null )"; then
      # Inherited property have a source of "inherited from <ancestor>";
      # non-inherited properties will not be printed with `-s inherited`
      if [ -n "${inherited}" ]; then
        zdebug "org.zfsbootmenu:commandline on ${zfsbe} is inherited, using parent expansion verbatim"
        echo "${par_args}"
        return 0
      fi
    fi
  fi

  echo "${args//%\{parent\}/${par_args}}"
  return 0
}

# arg1: ZFS filesystem
# arg2: path for a mounted filesystem
# prints: nothing
# returns: 0 on success

preload_be_cmdline() {
  local zfsbe_mnt zfsbe_fs zfsbe_args args_file

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

  args_file="${BASE}/${zfsbe_fs}/cmdline"

  if zfsbe_args="$( read_kcl_prop "${zfsbe_fs}" )" && [ -n "${zfsbe_args}" ]; then
    zdebug "using org.zfsbootmenu:commandline"
    echo "${zfsbe_args}" > "${args_file}"
    return
  fi

  if [ -n "${zfsbe_mnt}" ] && [ -r "${zfsbe_mnt}/etc/default/zfsbootmenu" ]; then
    zdebug "using ${zfsbe_mnt}/etc/default/zfsbootmenu"
    head -1 "${zfsbe_mnt}/etc/default/zfsbootmenu" | tr -d '\n' > "${args_file}"
    return
  fi

  if [ -n "${zfsbe_mnt}" ] && [ -r "${zfsbe_mnt}/etc/default/grub" ]; then
    zdebug "using ${zfsbe_mnt}/etc/default/grub"
    echo "$(
      # shellcheck disable=SC1090,SC1091
      . "${zfsbe_mnt}/etc/default/grub" ;
      echo "${GRUB_CMDLINE_LINUX_DEFAULT}"
    )" > "${args_file}"
    return
  fi
}

# arg1: key(and associated value) to suppress from KCL
# arg2..argN: kernel command line
# prints: supressed kernel command line with a trailing space
# returns: 0 on success

suppress_kcl_arg() {
  arg=$1
  shift

  if [ -z "${arg}" ]; then
    echo "$*"
    return 0
  fi

  awk <<< "$*" '
    BEGIN {
      quot = 0;
      supp = 0;
      ORS = " ";
    }

    {
      for (i=1; i <= NF; i++) {
        if ( quot == 0 ) {
          # If unquoted, determine if output should be suppressed
          if ( $(i) ~ /^'"${arg}"'=/ ) {
            # Suppress unwanted argument
             supp = 1;
          } else {
            # Nothing else is suppressed
            supp = 0;
          }
        }

        # If output is not suppressed, print the field
        if ( supp == 0 && length($(i)) > 0 ) {
          print $(i);
        }

        # If an odd number of quotes are in this field, toggle quoting
        if ( gsub(/"/, "\"", $(i)) % 2 == 1 ) {
          quot = (quot + 1) % 2;
        }
      }
    }
  '
}

# arg1: ZFS filesystem
# prints: kernel command line arguments
# returns: nothing

load_be_cmdline() {
  local zfsbe_fs zfsbe_args spl_hostid

  zfsbe_fs="${1}"
  if [ -z "${zfsbe_fs}" ]; then
    zerror "zfsbe_fs is undefined"
    return 1
  fi
  zdebug "zfsbe_fs set to ${zfsbe_fs}"

  # If a user-entered cmdline is found, it is not modified
  if [ -r "${BASE}/cmdline" ]; then
    zdebug "using ${BASE}/cmdline as commandline for ${zfsbe_fs}"
    head -1 "${BASE}/cmdline" | tr -d '\n'
    return
  fi

  # Use BE-specific cmdline if found, fall back to generic default
  zfsbe_args="quiet loglevel=4"
  if [ -r "${BASE}/${zfsbe_fs}/cmdline" ]; then
    zdebug "using ${BASE}/${zfsbe_fs}/cmdline as commandline for ${zfsbe_fs}"
    zfsbe_args="$(head -1 "${BASE}/${zfsbe_fs}/cmdline" | tr -d '\n')"
  fi

  if [ -e "${BASE}/noresume" ]; then
    zdebug "${BASE}/noresume set, processing: '${zfsbe_args}'"
    # Must replace resume= arguments and append a noresume
    zfsbe_args="$( suppress_kcl_arg resume "${zfsbe_args}" )noresume"
  fi

  # shellcheck disable=SC2154
  if [ "${zbm_set_hostid:-0}" -eq 1 ] && spl_hostid="$( get_spl_hostid )"; then
    zdebug "overriding spl_hostid and spl.spl_hostid in: '${zfsbe_args}'"
    zfsbe_args="$( suppress_kcl_arg spl_hostid "${zfsbe_args}" )"
    zfsbe_args="$( suppress_kcl_arg spl.spl_hostid "${zfsbe_args}" )"

    if [ "${spl_hostid}" = "0x00000000" ]; then
      # spl.spl_hostid=0 is a no-op; imports fall back to /etc/hostid.
      # Dracut writes spl_hostid to /etc/hostid. to yield expected results.
      # Others (initramfs-tools, mkinitcpio) ignore this, but there isn't much
      # else that can be done with those systems.
      zfsbe_args+="spl_hostid=00000000"
    else
      # Using spl.spl_hostid will set a module parameter which takes precedence
      # over any /etc/hostid and should produce expected behavior in all systems
      zfsbe_args+="spl.spl_hostid=${spl_hostid}"
    fi
  fi

  zdebug "processed commandline: '${zfsbe_args}'"
  echo "${zfsbe_args}"
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

  return ${ret}
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

  return ${ret}
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
  done <<<"$( zpool status "${pool}" )"

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

# arg1..argN: lines of warning message
# prints: warning message
# returns: 1 if user pressed ESC, 0 otherwise

timed_prompt() {
  local prompt x y cnum

  [ $# -gt 0 ] || return
  [ -n "${delay}" ] || delay="30"
  [ -n "${prompt}" ] || prompt="Press [RETURN] or wait %0.2d seconds to continue"

  [ "${delay}" -eq 0 ] && return

  # shellcheck disable=SC2154
  case "${color}" in
    red) cnum=1 ;;
    green) cnum=2 ;;
    yellow) cnum=3 ;;
    blue) cnum=4 ;;
    magenta) cnum=5 ;;
    cyan) cnum=6 ;;
    *) cnum="" ;;
  esac

  tput civis
  HEIGHT=$( tput lines )
  WIDTH=$( tput cols )
  tput clear

  x=$(( (HEIGHT - 0) / 2))
  [ "${x}" -lt 0 ] && x=0

  [ -n "${cnum}" ] && tput setaf "${cnum}"
  while [ $# -gt 0 ]; do
    local line=${1}
    y=$(( (WIDTH - ${#line}) / 2 ))
    [ "${y}" -lt 0 ] && y=0
    tput cup $x $y
    echo -n -e "${line}"
    x=$(( x + 1 ))
    shift
  done
  [ -n "${cnum}" ] && tput sgr0

  for (( i=delay; i>0; i-- )); do
    # shellcheck disable=SC2059
    mes="$( printf "${prompt}" "${i}" )"
    y=$(( (WIDTH - ${#mes}) / 2 ))
    [ "${y}" -lt 0 ] && y=0
    tput cup $x $y
    echo -ne "${mes}"

    # shellcheck disable=SC2162
    IFS='' read -s -N 1 -t 1 key
    # escape key
    if [ "$key" = $'\e' ]; then
      return 1
    # enter key
    elif [ "$key" = $'\x0a' ]; then
      return 0
    fi
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
	add the "noresume" argument yourself if necesary.

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

# arg1: pool name
# prints nothing
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

  # If force_export is set, skip evaluating if the pool is already read-write
  # shellcheck disable=SC2154
  [ -n "${force_export}" ] || ! is_writable "${pool}" || return 0

  zdebug "${pool} is not already writable"

  if grep -q "${pool}" "${BASE}/degraded" >/dev/null 2>&1; then
    zdebug "prohibited: ${BASE}/degraded is set"
    color=red delay=10 timed_prompt "Operation prohibited" "Pool '${pool}' cannot be imported read-write"
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

# arg1: ZFS filesystem
# prints: name of encryption root, if present
# returns: 0 if system has an encryption root, 1 otherwise

be_has_encroot() {
  local fs pool encroot

  fs="${1}"
  if [ -z "${fs}" ]; then
    zerror "fs is undefined"
    return 1
  fi
  zdebug "fs set to ${fs}"

  pool="${fs%%/*}"

  if [ "$( zpool list -H -o feature@encryption "${pool}" )" != "active" ]; then
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
    keystatus="$( zfs get -H -o value keystatus "${encroot}" )"
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

  if ! keysrc="$( zfs get -H -o value org.zfsbootmenu:keysource "${fs}" )"; then
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
  local fs keylocation keyfile keydir keysrc keycache mutex mnt ret

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
  mutex="${keycache}/.cachemutex"

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

  ret=1
  if [ -e "${mnt}/${keyfile}" ]; then
    keydir="${keyfile%/*}"
    if [ "${keydir}" != "${keyfile}" ] && [ -n "${keydir}" ]; then
      mkdir -p "${keycache}/${keydir}"
    fi

    if cp "${mnt}/${keyfile}" "${keycache}/${keyfile}"; then
      zdebug "copied key ${mnt}/${keyfile} to ${keycache}/${keyfile}"
      ret=0
    fi
  else
    zdebug "key file ${keysrc}:${keyfile} not found at ${mnt}/${keyfile}"
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
  local fs encroot key keypath keyformat keylocation keysource

  fs="${1}"
  if [ -z "${fs}" ]; then
    zerror "fs is undefined"
    return 1
  fi
  zdebug "fs set to ${fs}"

  # Nothing to do if filesystem is not locked
  if ! encroot="$( be_is_locked "${fs}" )" || [ -z "$encroot" ]; then
    return 0
  fi

  # Default to 0 when unset
  [ -n "${CLEAR_SCREEN}" ] || CLEAR_SCREEN=0
  [ -n "${NO_CACHE}" ] || NO_CACHE=0

  # If something goes wrong discovering key location, just prompt
  if ! keylocation="$( zfs get -H -o value keylocation "${encroot}" )"; then
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
  elif keysource="$( be_keysource "${fs}" )" && [ "${NO_CACHE}" -eq 0 ]; then
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
  keyformat="$( zfs get -H -o value keyformat "${encroot}" )" || keyformat=""
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

# arg1: path to BE list
# prints: nothing
# returns: 0 iff at least one valid BE was found

populate_be_list() {
  local be_list fs mnt active candidates ret sort_key

  be_list="${1}"
  if [ -z "${be_list}" ]; then
    zerror "be_list is undefined"
    return 1
  fi
  zdebug "be_list set to ${be_list}"

  sort_key="$( get_sort_key )"

  # Truncate the list to avoid stale entries
  : > "${be_list}"

  # Find valid BEs
  while IFS=$'\t' read -r fs mnt active; do
    if [ "${mnt}" = "/" ]; then
      # When mountpoint=/, BE is a candidate unless org.zfsbootmenu:active=off
      [ "${active}" = "off" ] && continue
    elif [ "${mnt}" = "legacy" ]; then
      # When mountpoint=legacy, BE is a candidate only if org.zfsbootmenu:active=on
      [ "${active}" = "on" ] || continue
    else
      # All other datasets are ignored
      continue
    fi
    if [ "${BOOTFS}" = "${fs}" ] ; then
      # If BOOTFS is defined, we'll manually append it to the array
      continue
    fi

    candidates+=( "${fs}" )
  done <<< "$(zfs list -H -o name,mountpoint,org.zfsbootmenu:active -S "${sort_key}")"

  # put bootfs on the end, so it is shown first with --tac
  [ -n "${BOOTFS}" ] && candidates+=( "${BOOTFS}" )

  ret=1
  for fs in "${candidates[@]}"; do
    # Unlock if necessary
    load_key "${fs}" || continue

    # Candidates are added to BE list if they have kernels in /boot
    if find_be_kernels "${fs}"; then
      echo "${fs}" >> "${be_list}"
      ret=0
    fi
  done
  return $ret
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
  local message
  message=${1:-unknown reason}

  tput clear
  tput cnorm
  stty echo

  echo -n "Launching emergency shell: "
  echo -e "${message}\n"
  /bin/bash -l
}

# prints: nothing
# returns: nothing

change_sort() {
  local zsa zrem

  zsa="${zbm_sort%%;*}"
  zrem="${zbm_sort#*;}"
  zbm_sort="${zrem};${zsa}"
  zdebug "Setting zbm_sort to ${zbm_sort}"
}

# prints: contents of $BASE/zbm.cmdline
# returns: nothing

zbmcmdline() {
  [ -f "${BASE}/zbm.cmdline" ] && echo | cat "${BASE}/zbm.cmdline" -
}

# arg1: pid
# prints: child pid
# returns: 0 if a child pid was found, 1 if there are no children

find_child_pid() {
  local pid child

  pid="${1}"
  if [ -z "${pid}" ]; then
    zdebug "empty pid"
    return 1
  fi

  if [ -e "/proc/${pid}/task/${pid}/children" ] ; then
    read -r child < "/proc/${pid}/task/${pid}/children"

    if [ -n "${child}" ] ; then
      echo "${child}"
      return 0
    fi
  fi

  return 1
}

# prints: nothing
# returns: nothing

takeover() {
  local pid child

  # Kill the other running instance
  if [ -e "${BASE}/active" ] ; then
    read -r pid < "${BASE}/active"
    parent=${pid}

    echo "Stopping active zfsbootmenu with a PID of ${pid}"

    # Trip the USR1 handler in /bin/zfsbootmenu - 'exit 0'
    zdebug "Sending USR1 to ${parent}"
    kill -USR1 "${parent}"

    # find the last child process of the active /bin/zfsbootmenu
    while child="$( find_child_pid "${parent}" )" ; do
      zdebug "Child pid of ${parent} is ${child}"
      if [ -n "${child}" ] ; then
        parent=${child}
        continue
      fi
      break
    done

    zdebug "Final child pid is ${parent}"

    # Kill the blocking child so that the USR1 handler actually executes
    [ -n "${parent}" ] && kill "${parent}"
  fi

  /bin/zfsbootmenu
}

# prints: nothing
# returns: 0

is_lib_sourced() {
  return 0
}
