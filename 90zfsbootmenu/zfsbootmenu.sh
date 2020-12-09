#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

##
# Look for BEs with kernels and present a selection menu
##

# shellcheck disable=SC1091
test -f /lib/zfsbootmenu-lib.sh && source /lib/zfsbootmenu-lib.sh
# shellcheck disable=SC1091
test -f zfsbootmenu-lib.sh && source zfsbootmenu-lib.sh

if [ -z "${BASE}" ]; then
  export BASE="/zfsbootmenu"
fi

while [ ! -e "${BASE}/initialized" ]; do
  if ! delay=5 prompt="Press [ESC] to cancel" timed_prompt "Waiting for ZFSBootMenu initialization"; then
    zdebug "exited while waiting for initialization"
    tput cnorm
    tput clear
    exit
  fi
done

while [ -e "${BASE}/active" ]; do
  if ! delay=5 prompt="Press [ESC] to cancel" timed_prompt "Waiting for other ZFSBootMenu instace to terminate"; then
    zdebug "exited while waiting to own ${BASE}/active"
    tput cnorm
    tput clear
    exit
  fi
done

# Prevent conflicting use of the boot menu
: > "${BASE}/active"
zdebug "creating ${BASE}/active"

# shellcheck disable=SC2064
trap "rm -f '${BASE}/active'" EXIT

if [ -r "${BASE}/bootfs" ]; then
  read -r BOOTFS < "${BASE}/bootfs"
  export BOOTFS
  zdebug "setting BOOTFS to ${BOOTFS}"
fi

# Run setup hooks, if they exist
if [ -d /libexec/setup.d ]; then
  tput clear
  for _hook in /libexec/setup.d/*; do
    zinfo "Processing hook: ${_hook}"
    [ -x "${_hook}" ] && "${_hook}"
  done
  unset _hook
fi

trap '' SIGINT

if command -v fzf >/dev/null 2>&1; then
  export FUZZYSEL=fzf
  #shellcheck disable=SC2016
  export FZF_DEFAULT_OPTS='--ansi --no-clear --layout=reverse-list --cycle --inline-info --tac --color=16 --bind "alt-h:execute[ /libexec/zfsbootmenu-help -L ${HELP_SECTION:-MAIN} ]"'
  export PREVIEW_HEIGHT=2
  zdebug "using fzf for pager"
elif command -v sk >/dev/null 2>&1; then
  export FUZZYSEL=sk
  #shellcheck disable=SC2016
  export SKIM_DEFAULT_OPTIONS='--ansi --no-clear --layout=reverse-list --inline-info --tac --color=16 --bind "alt-h:execute[ /libexec/zfsbootmenu-help -L ${HELP_SECTION:-MAIN} ]"'
  export PREVIEW_HEIGHT=3
  zdebug "using sk for pager"
fi

# The menu will not work if a fuzzy menu isn't available
if [ -z "${FUZZYSEL}" ]; then
  emergency_shell "no fuzzy menu available"
  exit
fi

# Clear screen before a possible password prompt
tput clear

BE_SELECTED=0

while true; do
  tput civis

  if [ ${BE_SELECTED} -eq 0 ]; then
    # Populate the BE list, load any keys as necessary
    if ! populate_be_list "${BASE}/env" || [ ! -f "${BASE}/env" ]; then
      color=red delay=10 timed_prompt \
        "No boot environments with kernels found" \
        "Dropping to an emergency shell to allow recovery attempts"
      tput clear
      tput cnorm
      exit 1
    fi

    bootenv="$( draw_be "${BASE}/env" )"
    ret=$?

    # key press
    # bootenv
    # shellcheck disable=SC2162
    IFS=, read key selected_be <<<"${bootenv}"
    zdebug "selected key: ${key}"

    if [ $ret -eq 0 ]; then
      BE_SELECTED=1
      zdebug "selected bootenv: ${selected_be}"
    fi
  fi

  if [ ${BE_SELECTED} -eq 1 ]; then
    # Either a boot will proceed, or the menu will be drawn fresh
    BE_SELECTED=0

    case "${key}" in
      "enter")
        if ! kexec_kernel "$( select_kernel "${selected_be}" )"; then
          zdebug "kexec failed for ${selected_be}"
          continue
        fi
        exit
        ;;
      "alt-k")
        selection="$( draw_kernel "${selected_be}" )"
        ret=$?

        # Only continue if a selection was made
        [ $ret -eq 0 ] || continue

        # shellcheck disable=SC2162
        IFS=, read subkey selected_kernel <<< "${selection}"
        zdebug "selected kernel: ${selected_kernel}"

        case "${subkey}" in
          "enter")
            if ! kexec_kernel "${selected_kernel}"; then
              zdebug "kexec failed for ${selected_kernel}"
              continue
            fi
            exit
            ;;
          "alt-d")
            # shellcheck disable=SC2034
            IFS=' ' read -r fs kpath initrd <<< "${selected_kernel}"
            set_default_kernel "${fs}" "${kpath}"
            ;;
        esac
        ;;
      "alt-p")
        selection="$( draw_pool_status )"
        ret=$?

        # Only continue if a selection was made
        [ $ret -eq 0 ] || continue

        # shellcheck disable=SC2162
        IFS=, read subkey selected_pool <<< "${selection}"
        zdebug "selected pool: ${selected_pool}"

        case "${subkey}" in
          "enter")
            continue
            ;;
          "alt-r")
            rewind_checkpoint "${selected_pool}"
            ;;
        esac
        ;;
      "alt-d")
        set_default_env "${selected_be}"
        echo "${BOOTFS}" > "${BASE}/bootfs"
        ;;
      "alt-s")
        selection="$( draw_snapshots "${selected_be}" )"
        ret=$?

        # Only continue if a selection was made
        [ $ret -eq 0 ] || continue

        # shellcheck disable=SC2162
        IFS=, read subkey selected_snap <<< "${selection}"
        zdebug "selected snapshot: ${selected_snap}"

        # Parent of the selected dataset, must be nonempty
        parent_ds="${selected_snap%/*}"
        [ -n "$parent_ds" ] || continue

        tput clear
        tput cnorm

        case "${subkey}" in
          "alt-d")
            draw_diff "${selected_snap}"
            BE_SELECTED=1
            continue
          ;;
          # Check available space early in the process
          "enter")
            avail_space_exact="$( zfs list -p -H -o available "${parent_ds}" )"
            be_size_exact="$( zfs list -p -H -o refer "${selected_snap}" )"
            leftover_space=$(( avail_space_exact - be_size_exact ))
            if [ "${leftover_space}" -le 0 ]; then
              avail_space="$( zfs list -H -o available "${parent_ds}" )"
              be_size="$( zfs list -H -o refer "${selected_snap}" )"
              color=red delay=10 timed_prompt "Insufficient space for duplication" \
                "'${parent_ds}' has ${avail_space} free but needs ${be_size}"
              continue
            fi
          ;;
        esac

        # Strip parent datasets
        pre_populated="${selected_snap##*/}"
        # Strip snapshot name and append NEW
        pre_populated="${pre_populated%%@*}_NEW"

        while true;
        do
          echo -e "\nNew boot environment name"
          new_be="$( /libexec/zfsbootmenu-input "${pre_populated}" )"

          if [ -z "${new_be}" ] ; then
            break
          fi

          if [ -n "${new_be}" ] ; then
            valid_name=$( echo "${new_be}" | tr -c -d 'a-zA-Z0-9-_.,' )
            # If the entered name is invalid, set the prompt to the valid form of the name
            if [[ "${new_be}" != "${valid_name}" ]]; then
              echo "${new_be} is invalid, ${valid_name} can be used"
              pre_populated="${valid_name}"
            elif zfs list -H -o name "${parent_ds}/${new_be}" >/dev/null 2>&1; then
              echo "${new_be} already exists, please use another name"
              pre_populated="${new_be}"
            else
              break
            fi
          fi
        done

        # Must have a nonempty name for the new BE
        [ -n "${new_be}" ] || continue

        clone_target="${parent_ds}/${new_be}"
        be_size="$( zfs list -H -o refer "${selected_snap}" )"
        echo -e "\nCreating ${clone_target} from ${selected_snap} (${be_size})"

        case "${subkey}" in
          "enter")
            duplicate_snapshot "${selected_snap}" "${clone_target}"
            ;;
          "alt-x")
            clone_snapshot "${selected_snap}" "${clone_target}"
            ;;
          "alt-c")
            clone_snapshot "${selected_snap}" "${clone_target}" "nopromote"
            ;;
        esac
        ;;
      "alt-r")
        break
        ;;
      "alt-w")
        pool="${selected_be%%/*}"
        need_key=0

        if is_writable "${pool}"; then
          if export_pool "${pool}" && read_write='' import_pool "${pool}"; then
            need_key=1
          fi
        elif set_rw_pool "${pool}"; then
          need_key=1
        fi

        if [ "$need_key" -eq 1 ]; then
          CLEAR_SCREEN=1 load_key "${selected_be}"
        fi
        ;;
      "alt-c")
        tput clear
        tput cnorm

        echo ""
        /libexec/zfsbootmenu-preview "${BASE}" "${selected_be}" "${BOOTFS}"

        BE_ARGS="$( load_be_cmdline "${selected_be}" )"
        while IFS= read -r line; do
          def_args="${line}"
        done <<< "${BE_ARGS}"

        echo -e "\nNew kernel command line"
        cmdline="$( /libexec/zfsbootmenu-input "${def_args}" )"

        if [ -n "${cmdline}" ] ; then
          echo "${cmdline}" > "${BASE}/cmdline"
        fi
        ;;
      "alt-e")
        tput clear
        tput cnorm
        zdebug "chroot environment: ${selected_be}"
        echo "Entering chroot for ${selected_be}"
        /bin/bash -c "zfs-chroot ${selected_be}"
      ;;
    esac
  fi
done
