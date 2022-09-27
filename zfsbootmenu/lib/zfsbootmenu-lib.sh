#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

[ -n "${_ZFSBOOTMENU_LIB}" ] && return
readonly _ZFSBOOTMENU_LIB=1

# shellcheck disable=SC1091
source /lib/zfsbootmenu-core.sh >/dev/null 2>&1 || exit 1

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

# arg1: colon-delimited string
# arg2: short string used when column is missing / display is small
# prints: string, columnized
# returns: nothing

column_wrap() {
  local footer max pad
  footer="${1}"

  if [ "${COLUMNS:-0}" -lt 80 ] || [ -z "${HAS_COLUMN}" ] ; then
    # Use shorter footer text, if it exists
    [ -n "${2}" ] && footer="${2}"
    shopt -s extglob
    # Collapse repeated colons into a single
    footer="${footer//+([:])/:}"
    footer="${footer//:/$'\n'}"
    shopt -u extglob
  else 
    footer="$( echo -e "${footer}" | column -t -s ':' )"
  fi
  
  # Determine the longest line of help text, for alignment purposes
  max="$( echo -e "${footer}" | awk -v l=0 'length>l {l=length}; END{print l}' )"
  # remove an extra 3 - 1 for '^', 2 for the fzf gutter
  printf -v pad "%*s" $(( ( COLUMNS - max - 3 ) / 2 )) ''

  # colorize [KEY] text
  footer="${footer//\[/\\033\[0;32m\[}"
  footer="${footer//\]/\]\\033\[0m}"

  # swap out '^' for a padded string, print
  echo -e "${footer//^/${pad}}"
}


# args: optional page to mark as active
# prints: writes a string directly to the controlling terminal
# returns: nothing

# shellcheck disable=SC2120
draw_page() {
  local header hlen page tab

  if [ -z "${1}" ]; then
    page="${FUNCNAME[1]}"
  else
    # Optionally use the help page text to indicate what to highlight
    page="${1}"
  fi

  header="Boot Environments | Snapshots | Kernels | Pool Status | Logs | Help"
  hlen="${#header}"

  case "${page}" in
    draw_be|main-screen)
      tab="$( colorize red "Boot Environments" )"
      header="${header/Boot Environments/${tab}}"
      ;;
    draw_kernel|kernel-management)
      tab="$( colorize red "Kernels" )"
      header="${header/Kernels/${tab}}"
      ;;
    draw_snapshots|snapshot-management)
      tab="$( colorize red "Snapshots" )"
      header="${header/Snapshots/${tab}}"
      ;;
    draw_pool_status|zpool-health)
      tab="$( colorize red "Pool Status" )"
      header="${header/Pool Status/${tab}}"
      ;;
    help_pager)
      tab="$( colorize red "Help" )"
      header="${header/Help/${tab}}"
      ;;
    log_tail)
      tab="$( colorize red "Logs" )"
      header="${header/Logs/${tab}}"
      ;;
    *)
      zdebug "Called from unknown function: ${page}"
      ;;
  esac

  # Write directly to the row (0), column (whatever centers us) on the controlling terminal
  # This function can't write to stdout, because it's called from inside draw_kernel/draw_be/etc,
  # and doing so will break the return text from those functions

  [ -z "${COLUMNS}" ] && COLUMNS="$( tput cols )"
  # shellcheck disable=SC2154
  echo -n -e "\033[50D\033[$(( ( COLUMNS - hlen ) / 2 ))C${header}" > "${control_term}"
}

# arg1: Path to file with detected boot environments, 1 per line
# prints: key pressed, boot environment on successful selection
# returns: 0 on successful selection, 1 if Esc was pressed, 130 if BE list is missing

draw_be() {
  local env selected header expects kcl_text kcl_bind blank

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

  if [ -f "${BASE}/cmdline" ]; then
    kcl_text="[CTRL+T] revert kcl"
    kcl_bind="alt-t"
    blank=
  else
    blank=':'
  fi

  empty="                         "
  header="$( column_wrap "\
^[RETURN] boot:[ESCAPE] refresh view:[CTRL+P] pool status
^[CTRL+D] set bootfs:[CTRL+S] snapshots:[CTRL+K] kernels
^[CTRL+E] edit kcl:[CTRL+J] jump into chroot:[CTRL+R] recovery shell
^${kcl_text:+${kcl_text}:}[CTRL+L] view logs:${blank}[CTRL+H] help" \
"\
^[RETURN] boot
^[CTRL+R] recovery shell
^[CTRL+H] help" )"

  expects="--expect=alt-e,alt-k,alt-d,alt-s,alt-c,alt-r,alt-p,alt-w,alt-j,alt-o${kcl_bind:+,${kcl_bind}}"

  if ! selected="$( draw_page ; ${FUZZYSEL} --height=$(( LINES - 1 )) -0 --prompt "BE > " \
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

  header="$( column_wrap "\
^[RETURN] boot:[ESCAPE] back
^[CTRL+D] set default:[CTRL+U] unset default
^[CTRL+L] view logs:[CTRL+H] help" \
"\
^[RETURN] boot
^[CTRL+D] set default
^[CTRL+H] help" )"

  expects="--expect=alt-d,alt-u"

  if ! selected="$( draw_page ; HELP_SECTION=kernel-management ${FUZZYSEL} \
      --height=$(( LINES - 1 )) \
      --prompt "${benv} > " --tac --with-nth=2 --header="${header}" \
      ${expects} ${expects//alt-/ctrl-} ${expects//alt-/ctrl-alt-} \
      --preview="/libexec/zfsbootmenu-preview ${benv} ${BOOTFS}"  \
      --preview-window="up:${PREVIEW_HEIGHT}" < "${_kernels}" )"; then
    return 1
    tput clear
  fi
  tput clear

  # shellcheck disable=SC2119
  selected="$( csv_cat <<< "${selected}" )"
  echo "${selected}"
  zdebug "selected: ${selected}"

  return 0
}

# arg1: ZFS filesystem name
# prints: selected snapshot name, optionally a second snapshot
# returns: 130 on error, 0 otherwise

draw_snapshots() {
  local benv selected header expects sort_key snapshots

  benv="${1}"
  if [ -z "${benv}" ]; then
    zerror "benv is undefined"
    return 130
  fi
  zdebug "using boot environment: ${benv}"

  sort_key="$( get_sort_key )"

  header="$( column_wrap "\
^[RETURN] duplicate:[CTRL+C] clone only:[CTRL+X] clone and promote
^[CTRL+D] show diff:[CTRL+R] rollback:[CTRL+N] create new snapshot
^[CTRL+L] view logs::[CTRL+J] jump into chroot
^[CTRL+H] help::[ESCAPE] back" \
"\
^[RETURN] duplicate
^[CTRL+D] show diff
^[CTRL+H] help" )"

  context="Note: for diff viewer, use tab to select/deselect up to two items"

  expects="--expect=alt-x,alt-c,alt-j,alt-o,alt-n,alt-r"

  # ${snapshots} must always be defined so that the mod-n handler can be executed
  snapshots="$( zfs list -t snapshot -H -o name "${benv}" -S "${sort_key}" )"
  snapshots="${snapshots:-No snaphots available}"

  zdebug "snapshots: ${snapshots[*]}"

  if ! selected="$( draw_page ; HELP_SECTION=snapshot-management ${FUZZYSEL} \
        --height=$(( LINES - 1 )) \
        --prompt "Snapshot > " --header="${header}" --tac --multi 2 \
        ${expects} ${expects//alt-/ctrl-} ${expects//alt-/ctrl-alt-} \
        --bind='alt-d:execute[ /libexec/zfunc draw_diff {+} ]' \
        --bind='ctrl-d:execute[ /libexec/zfunc draw_diff {+} ]' \
        --bind='ctrl-alt-d:execute[ /libexec/zfunc draw_diff {+} ]' \
        --preview="/libexec/zfsbootmenu-preview ${benv} ${BOOTFS} '${context}'" \
        --preview-window="up:$(( PREVIEW_HEIGHT + 1 ))" <<<"${snapshots}" )"; then
    return 1
    tput clear
  fi
  tput clear

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
  local snapshot diff_target pool base_fs mnt
  local zfs_diff zfs_diff_PID
  local line_one line_two left_pad

  snapshot="${1}"
  if [ -z "${snapshot}" ]; then
    zerror "snapshot is undefined"
    return 130
  fi

  # if a second parameter was passed in and it's a snapshot, compare
  # creation dates and make sure diff_target is newer than snapshot
  if [ -n "${2}" ] ; then
    local sd td
    sd="$( zfs get -H -p -o value creation "${snapshot}" )"
    td="$( zfs get -H -p -o value creation "${2}" )"
    if [ "${sd}" -lt "${td}" ] ; then
      diff_target="${2}"
    else
      diff_target="${snapshot}"
      snapshot="${2}"
    fi
  else
    diff_target="${snapshot%%@*}"
  fi

  zdebug "snapshot: ${snapshot}"
  zdebug "diff target: ${diff_target}"

  pool="${snapshot%%/*}"
  zdebug "pool: ${pool}"

  if ! set_rw_pool "${pool}"; then
    zerror "unable to set ${pool} read/write"
    return
  fi

  base_fs="${snapshot%%@*}"
  zdebug "base filesystem: ${base_fs}"

  CLEAR_SCREEN=1 load_key "${base_fs}"

  if ! mnt="$( mount_zfs "${base_fs}" )" ; then
    zerror "unable to mount ${base_fs}"
    return
  fi

  zdebug "executing: zfs diff -F -H ${snapshot} ${diff_target}"
  coproc zfs_diff ( zfs diff -F -H "${snapshot}" "${diff_target}" )

  # Bash won't use an FD referenced in a variable on the left side of a pipe
  exec 3>&"${zfs_diff[0]}"

  # shellcheck disable=SC2154
  line_one="$( center_string "---${snapshot}" )"
  left_pad="${line_one//---${snapshot}/}"
  line_one="$( colorize red "${line_one}" )"
  line_two="${left_pad}$( colorize green "+++${diff_target}" )"

  sed "s,${mnt},," <&3 | HELP_SECTION=diff-viewer ${FUZZYSEL} --prompt "> " \
    --preview="echo -e '${line_one}\n${line_two}'" --no-sort \
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
  header="$( column_wrap "\
[ESCAPE] back
[CTRL+R] rewind checkpoint
[CTRL+L] view logs
[CTRL+H] help" )"

  if ! selected="$( draw_page ; zpool list -H -o name |
      HELP_SECTION=zpool-health ${FUZZYSEL} \
      --height=$(( LINES - 1 )) \
      --prompt "Pool > " --tac --expect=alt-r,ctrl-r,ctrl-alt-r \
      --preview-window="right:${psize}" \
      --preview="zpool status -v {}" --header="${header}" )"; then
    return 1
  fi
  tput clear

  # shellcheck disable=SC2119
  selected="$( csv_cat <<< "${selected}" )"
  echo "${selected}"
  zdebug "selected: ${selected}"

  return 0
}

# arg1: selected snapshot
# arg2: subkey
# prints: snapshot/filesystem creation prompt
# returns: nothing

snapshot_dispatcher() {
  local selected subkey
  local parent_ds avail_space_exact be_size_exact leftover_space avail_space be_size
  local prompt header check_base pre_populated user_input valid_name clone_target

  selected="${1}"
  if [ -z "$selected" ]; then
    zerror "selected is undefined"
    return 1
  fi
  zdebug "selected: ${selected}"

  subkey="${2}"
  if [ -z "$subkey" ]; then
    zerror "subkey is undefined"
    return 1
  fi
  zdebug "subkey: ${subkey}"

  if [ "${subkey}" = "mod-r" ]; then
    rollback_snapshot "${selected}"
    return
  fi

  parent_ds="${selected%/*}"

  # Generally, stripping "/*" from $selected will also drop the snapshot part;
  # however, if $selected is the root dataset, $parent_ds == $selected because
  # $selected contains no "/". In that case, the snapshot must be stripped too.
  parent_ds="${parent_ds%@*}"

  if [ -z "${parent_ds}" ]; then
    zerror "unable to determine parent dataset for ${selected}"
    return 1
  fi
  zdebug "parent_ds: ${parent_ds}"

  if [ "${subkey}" = "enter" ]; then
      # Do space calculations; bail early
      avail_space_exact="$( zfs list -p -H -o available "${parent_ds}" )"
      be_size_exact="$( zfs list -p -H -o refer "${selected}" )"
      leftover_space=$(( avail_space_exact - be_size_exact ))
      if [ "${leftover_space}" -le 0 ]; then
        avail_space="$( zfs list -H -o available "${parent_ds}" )"
        be_size="$( zfs list -H -o refer "${selected}" )"
        zerror "Insufficient space for duplication, ${parent_ds}' has ${avail_space} free but needs ${be_size}"
        timed_prompt -m "$( colorize red "Insufficient space for duplication" )" \
          -m "'$( colorize magenta "${parent_ds}" )' has ${avail_space} free but needs ${be_size}"
        return 1
      fi
  fi

  # Set prompt, header, existing check prefix
  case "${subkey}" in
    "enter"|"mod-x"|"mod-c")
      prompt="\nNew boot environment name (CTRL-C or leave blank to abort)"
      header="$( center_string "${selected}" )"
      check_base="${parent_ds}/"

      pre_populated="${selected##*/}"
      pre_populated="${pre_populated%%@*}_NEW"
      ;;
    "mod-n")
      prompt="\nNew snapshot name (CTRL-C or leave blank to abort)"
      header="$( center_string "${selected%%@*}" )"
      check_base="${selected%%@*}@"

      pre_populated="$( printf "%(%Y-%m-%d-%H%M%S)T" )"
      ;;
  esac

  tput clear
  tput cnorm
  colorize green "${header}"

  while true; do
    echo -e "${prompt}"
    user_input="$( /libexec/zfsbootmenu-input "${pre_populated}" )"

    [ -n "${user_input}" ] || return

    shopt -s extglob
    valid_name="${user_input//+([!a-zA-Z0-9-_.:])/}"
    shopt -u extglob

    if [[ "${user_input}" != "${valid_name}" ]]; then
      echo "${user_input} is invalid, ${valid_name} can be used"
      pre_populated="${valid_name}"
    elif zfs list -H -o name "${check_base}${user_input}" >/dev/null 2>&1; then
      echo "${check_base}${user_input} already exists, please use another name"
      pre_populated="${user_input}"
    else
      break
    fi
  done

  [ -n "${user_input}" ] || return

  # Print what we're doing for anything but snapshot creation
  case "${subkey}" in
    "enter"|"mod-x"|"mod-c")
      clone_target="${parent_ds}/${user_input}"
      be_size="$( zfs list -H -o refer "${selected}" )"
      echo -e "\nCreating ${clone_target} from ${selected} (${be_size})"
      ;;
  esac

  # Finally, dispatch to one of the snapshot handler functions
  case "${subkey}" in
    "enter")
      duplicate_snapshot "${selected}" "${clone_target}"
      ;;
    "mod-x")
      PROMOTE=1 clone_snapshot "${selected}" "${clone_target}"
      ;;
    "mod-c")
      clone_snapshot "${selected}" "${clone_target}"
      ;;
    "mod-n")
      create_snapshot "${selected%%@*}" "${user_input}"
      # shellcheck disable=SC2034
      BE_SELECTED=1
      ;;
  esac
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

  if [ -e "${BASE}/active" ] ; then
    read -r pid < "${BASE}/active"
    parent=${pid}

    zinfo "Stopping active zfsbootmenu with a PID of ${pid}"

    # Trip the USR1 handler in /bin/zfsbootmenu - 'exit 0'
    zdebug "sending USR1 to ${parent}"
    kill -USR1 "${parent}"

    # find the last child process of the active /bin/zfsbootmenu
    while child="$( find_child_pid "${parent}" )" ; do
      if [ -n "${child}" ] ; then
        parent=${child}
        continue
      fi
      break
    done

    # Kill the blocking child so that the USR1 handler actually executes
    zdebug "killing child process ${parent}"
    [ -n "${parent}" ] && kill "${parent}"
  fi
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

# prints: first sort key
# returns: nothing

get_sort_key() {
  local sort_key
  sort_key="${zbm_sort%%;*}"
  zdebug "Using sorting key ${sort_key}"
  echo -n "${sort_key:-name}"
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
    # Remove any existing cmdline cache
    rm -f "${BASE}/${fs}/cmdline"

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
