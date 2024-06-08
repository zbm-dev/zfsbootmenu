#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

[ -n "${_ZFSBOOTMENU_UI}" ] && return
readonly _ZFSBOOTMENU_UI=1

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
  local footer max lpad pad
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

  # Find the number of characters in the longest line
  max="$( echo -e "${footer}" | awk 'BEGIN{l=0} length>l {l=length}; END{print l}' )"

  # remove an extra 3 - 1 for '^', 2 for the fzf gutter
  lpad="$(( (COLUMNS - max - 3) / 2 ))"

  [[ ${lpad} -gt 0 ]] && printf -v pad "%*s" "${lpad}" ''

  footer="${footer//\[/\\033\[0;32m\[}"
  footer="${footer//\]/\]\\033\[0m}"

  echo -e "${footer//^/${pad}}"
}

# arg1: optional page to mark as active
# prints: a header string with the active page highlighted yellow
# returns: nothing

# shellcheck disable=SC2120
global_header() {
  local header page tab replacement

  page="${FUNCNAME[1]}"

  # 'main' isn't unique, so switch to the name of the script
  if [ "${page}" = "main" ]; then
    page="${0##*/}"
  fi

  # Set the entire string to one color
  header="\\033[0;37m Boot Environments - Snapshots - Kernels - Pool Status \\033[0m"

  case "${page}" in
    draw_be)
      tab="Boot Environments"
      ;;
    draw_kernel)
      tab="Kernels"
      ;;
    draw_snapshots)
      tab="Snapshots"
      ;;
    zfsbootmenu-diff)
      tab="Snapshots"
      replacement="Diff Viewer"
      ;;
    draw_pool_status)
      tab="Pool Status"
      ;;
    help_pager)
      header="\\033[0;37m Help \\033[0m"
      tab="Help"
      ;;
    zlogtail|logs)
      header="\\033[0;37m Logs \\033[0m"
      tab="Logs"
      ;;
    *)
      zdebug "Called from unknown function: ${page}"
      ;;
  esac

  # change the name of the selected tab to be yellow
  echo -n -e "${header/${tab}/\\033[1;33m[ ${replacement:-${tab}} ]\\033[0;37m}"
}

# arg1: Path to file with detected boot environments, 1 per line
# prints: key pressed, boot environment on successful selection
# returns: 0 on successful selection, 1 if Esc was pressed, 130 if BE list is missing

draw_be() {
  local env selected header expects kcl_text kcl_bind blank sort_key preview_label

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

  header="$( column_wrap "\
^[RETURN] boot:[CTRL+K] kernels:[CTRL+P] pool status
^[CTRL+D] set bootfs:[CTRL+J] jump into chroot:[CTRL+L] view logs
^[CTRL+S] snapshots:[CTRL+R] recovery shell:[CTRL+X] power menu
^[CTRL+E] edit kcl${kcl_text:+:${kcl_text}}:${blank}[CTRL+H] help" \
"\
^[RETURN] boot
^[CTRL+R] recovery shell
^[CTRL+H] help" )"

  sort_key="$( get_sort_key )"
  preview_label="Sorted by: ${sort_key^}"

  expects="--expect=alt-e,alt-k,alt-d,alt-s,alt-c,alt-r,alt-p,alt-w,alt-j,alt-o,alt-x${kcl_bind:+,${kcl_bind}},right"

  # shellcheck disable=SC2086
  if ! selected="$( ${FUZZYSEL} -0 --prompt "BE > " \
      ${expects} ${expects//alt-/ctrl-} ${expects//alt-/ctrl-alt-} \
      ${HAS_BORDER:+--border-label="$( global_header )"} \
      ${HAS_BORDER:+--preview-label-pos=2:bottom} \
      ${HAS_BORDER:+--preview-label="$( colorize orange " ${preview_label} " )"} \
      --header="${header}" --preview-window="up:${PREVIEW_HEIGHT}${HAS_BORDER:+,border-sharp}" \
      --preview="/libexec/zfsbootmenu-preview {} '${BOOTFS}'" < "${env}" )"; then
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

  _kernels="$( be_location "${benv}" )/kernels"
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

  expects="--expect=alt-d,alt-u,left,right"

  if ! selected="$( HELP_SECTION=kernel-management ${FUZZYSEL} \
      --prompt "${benv} > " --tac --delimiter=$'\t' --with-nth=2 \
      --header="${header}" ${HAS_BORDER:+--border-label="$( global_header )"} \
      ${expects} ${expects//alt-/ctrl-} ${expects//alt-/ctrl-alt-} \
      --preview="/libexec/zfsbootmenu-preview '${benv}' '${BOOTFS}'"  \
      --preview-window="up:${PREVIEW_HEIGHT}${HAS_BORDER:+,border-sharp}" < "${_kernels}" )"; then
    return 1
  fi

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
  local benv selected header expects sort_key snapshots note sorted_by context

  benv="${1}"
  if [ -z "${benv}" ]; then
    zerror "benv is undefined"
    return 130
  fi
  zdebug "using boot environment: ${benv}"

  header="$( column_wrap "\
^[RETURN] duplicate:[CTRL+C] clone only:[CTRL+X] clone and promote
^[CTRL+D] show diff:[CTRL+R] rollback:[CTRL+N] create new snapshot
^[CTRL+L] view logs::[CTRL+J] jump into chroot
^[CTRL+H] help::[ESCAPE] back" \
"\
^[RETURN] duplicate
^[CTRL+D] show diff
^[CTRL+H] help" )"

  sort_key="$( get_sort_key )"

  sorted_by="Sorted by: ${sort_key^}"
  note="Note: for diff viewer, use tab to select/deselect up to two items"

  local LEGACY_CONTEXT
  if [ -n "${HAS_BORDER}" ] ; then

    # Determine how much space should be between the 'sorted by' text and a centered note
    # Remove 4 extra characters so that we can put a 1 character pad between strings and 
    # the horizontal box line

    local spacer preview_offset

    spacer=$(( ( ( COLUMNS - ${#note} ) / 2 ) - ${#sorted_by} - 4 ))

    # preview_offset, if defined, controls the initial preview label text position
    # refer to fzf documentation for the --preview-label-pos flag

    # if spacer length is non-negative, everything fits
    if [ "${spacer}" -gt 0 ]; then
      preview_offset="2:"
      printf -v spacer "%*s" "${spacer}" ""
      # This is a unicode light solid line, U+2500
      spacer="${spacer// /─}"
      note="$( colorize orange "${note}" )"
      sorted_by="$( colorize orange "${sorted_by}" )"
      printf -v context " %s %s %s " "${sorted_by}" "${spacer}" "${note}"
    # fall back to seeing if the note fits in the available columns
    elif [ ${COLUMNS} -gt $(( ${#note} + 2 )) ]; then
      printf -v context " %s " "$( colorize orange "${note}" )"
    # very few screens will be narrower than this ...
    elif [ ${COLUMNS} -gt $(( ${#sorted_by} +2 )) ]; then
      preview_offset="2:"
      printf -v context " %s " "$( colorize orange "${sorted_by}" )"
    # this is a truly narrow screen, skip all preview label text
    else
      context=""
    fi
  else

    # when defined this controls passing an additional parameter to zfsbootmenu-preview
    # as well as extending the preview window height by 1
    # when undefined, it triggers adding 0 to the window height, leaving it as-is

    LEGACY_CONTEXT=1
    context="${note}"
  fi

  expects="--expect=alt-x,alt-c,alt-j,alt-o,alt-n,alt-r,left,right"

  # ${snapshots} must always be defined so that the mod-n handler can be executed
  snapshots="$( zfs list -t snapshot -H -o name -S "${sort_key}" "${benv}" )"
  snapshots="${snapshots:-No snapshots available}"

  zdebug "snapshots: ${snapshots[*]}"

  if ! selected="$(\
      HELP_SECTION=snapshot-management ${FUZZYSEL} \
        --prompt "Snapshot > " --header="${header}" --tac --multi 2 \
        ${HAS_BORDER:+--border-label="$( global_header )"} \
        ${expects} ${expects//alt-/ctrl-} ${expects//alt-/ctrl-alt-} \
        --bind="alt-d:execute[ /libexec/zfsbootmenu-diff {+} ]${HAS_REFRESH:++refresh-preview}" \
        --bind="ctrl-d:execute[ /libexec/zfsbootmenu-diff {+} ]${HAS_REFRESH:++refresh-preview}" \
        --bind="ctrl-alt-d:execute[ /libexec/zfsbootmenu-diff {+} ]${HAS_REFRESH:++refresh-preview}" \
        ${HAS_BORDER:+--preview-label-pos=${preview_offset:+${preview_offset}}bottom} \
        ${HAS_BORDER:+--preview-label="${context}"} \
        --preview="/libexec/zfsbootmenu-preview '${benv}' '${BOOTFS}' ${LEGACY_CONTEXT:+\"${context}\"}" \
        --preview-window="up:$(( PREVIEW_HEIGHT + ${LEGACY_CONTEXT:-0} ))${HAS_BORDER:+,border-sharp}" <<<"${snapshots}" )"
  then
    return 1
  fi

  # shellcheck disable=SC2119
  selected="$( csv_cat <<< "${selected}" )"
  echo "${selected}"
  zdebug "selected: ${selected}"

  return 0
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

  expects="--expect=left"

  if ! selected="$( zpool list -H -o name |
      HELP_SECTION=zpool-health ${FUZZYSEL} \
      --prompt "Pool > " --tac --expect=alt-r,ctrl-r,ctrl-alt-r \
      ${expects} ${expects//alt-/ctrl-} ${expects//alt-/ctrl-alt-} \
      ${HAS_BORDER:+--border-label="$( global_header )"} \
      --preview-window="right:${psize}${HAS_BORDER:+,border-sharp}" \
      --preview="zpool status -v {}" --header="${header}" )"; then
    return 1
  fi

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

# prints: potential boot environments, one per line
# returns: 0 if any candidate was found, 1 otherwise

find_be_candidates() {
  local fs mnt active ret sort_key list_fields have_bootfs

  list_fields="name,canmount,mountpoint,org.zfsbootmenu:active"
  sort_key="$( get_sort_key )"

  ret=1
  have_bootfs=
  while IFS=$'\t' read -r fs canmount mnt active; do
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

    # If BOOTFS is defined, we'll manually append it to the array
    if [ "${BOOTFS}" = "${fs}" ] ; then
      have_bootfs="yes"
      continue
    fi

    # root datasets should never be automatically mounted by the boot environment
    if [ "${canmount}" = "on" ]; then
      zwarn "canmount=on set for '${fs}', should be canmount=noauto"
    fi

    echo "${fs}"
    ret=0
  done <<< "$( zfs list -H -o "${list_fields}" -S "${sort_key}" )"

  # put bootfs at the end
  if [ -n "${BOOTFS}" ] && [ -n "${have_bootfs}" ]; then
    echo "${BOOTFS}"
    ret=0
  fi

  return "${ret}"
}

# arg1: path to BE list
# prints: nothing
# returns: 0 iff at least one valid BE was found

populate_be_list() {
  local be_list fs ret candidates

  be_list="${1}"
  if [ -z "${be_list}" ]; then
    zerror "be_list is undefined"
    return 1
  fi
  zdebug "be_list set to ${be_list}"

  # Truncate the list to avoid stale entries
  : > "${be_list}"

  readarray -t candidates <<< "$( find_be_candidates 2>/dev/null )"

  ret=1
  for fs in "${candidates[@]}"; do
    # Remove any existing cmdline cache
    rm -f "$( be_location "${fs}" )/cmdline"

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

# arg1: header/title text
# arg2..N: prompt options in the form "action:display text"
# prints: selected action
# returns: nothing

draw_modal_prompt() {
  local -i ROWS COLS LMARGIN TMARGIN maxlen=10 nopts=0
  local PROMPT="" OUTPUT TITLE disp action text

  TITLE=" ${1} "
  if (( "${#TITLE}" > maxlen )); then
    maxlen="${#TITLE}"
  fi
  shift

  for itm; do
    disp="${itm#*:}"
    if (( "${#disp}" > maxlen )); then
      maxlen="${#disp}"
    fi
    PROMPT+="${itm}"$'\n'
    nopts=$(( nopts + 1 ))
  done
  PROMPT+=":Cancel"
  nopts=$(( nopts + 1 ))

  ROWS="$(tput lines)"
  COLS="$(tput cols)"

  LMARGIN=$(( (COLS - maxlen - 6) / 2 ))
  TMARGIN=$(( (ROWS - nopts - 3) / 2 ))

  if OUTPUT="$(echo -e "${PROMPT}" | \
    fzf --no-info \
      --with-nth="2.." \
      --delimiter=":" \
      --no-multi \
      --no-sort \
      ${HAS_BORDER:+--border=sharp} \
      ${HAS_BORDER:+--border-label="${TITLE}"} \
      --prompt="> " \
      --layout=default \
      --no-scrollbar \
      --margin "${TMARGIN},${LMARGIN}")"; then
    # shellcheck disable=SC2034
    IFS=":" read -r action text <<< "${OUTPUT}"
    printf "%s" "$action"
  fi
}
