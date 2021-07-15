#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

if [ -r "/etc/profile" ]; then
  # shellcheck disable=SC1091
  source /etc/profile
else
  # shellcheck disable=SC1091
  source /lib/zfsbootmenu-lib.sh
  zwarn "failed to source ZBM environment"
fi

# Prove that /lib/zfsbootmenu-lib.sh was sourced, or hard fail
if ! is_lib_sourced > /dev/null 2>&1 ; then
  echo -e "\033[0;31mWARNING: /lib/zfsbootmenu-lib.sh was not sourced; unable to proceed\033[0m"
  exec /bin/bash
fi

# Make sure /dev/zfs exists, otherwise drop to a recovery shell
[ -e /dev/zfs ] || emergency_shell "/dev/zfs missing, check that kernel modules are loaded"

if [ -z "${BASE}" ]; then
  export BASE="/zfsbootmenu"
fi

mkdir -p "${BASE}"

while [ ! -e "${BASE}/initialized" ]; do
  if ! delay=5 prompt="Press [ESC] to cancel" timed_prompt "Waiting for ZFSBootMenu initialization"; then
    zdebug "exited while waiting for initialization"
    tput cnorm
    tput clear
    exit
  fi
done

while [ -e "${BASE}/active" ]; do
  if ! delay=5 prompt="Press [ESC] to cancel" timed_prompt "Waiting for other ZFSBootMenu instance to terminate"; then
    zdebug "exited while waiting to own ${BASE}/active"
    tput cnorm
    tput clear
    exit
  fi
done

# Prevent conflicting use of the boot menu
echo "$$" > "${BASE}/active"
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

# shellcheck disable=SC2016
fuzzy_default_options=( "--ansi" "--no-clear"
  "--layout=reverse-list" "--inline-info" "--tac" "--color=16"
  "--bind" '"alt-h:execute[ /libexec/zfsbootmenu-help -L ${HELP_SECTION:-main-screen} ]"'
  "--bind" '"ctrl-h:execute[ /libexec/zfsbootmenu-help -L ${HELP_SECTION:-main-screen} ]"'
  "--bind" '"ctrl-alt-h:execute[ /libexec/zfsbootmenu-help -L ${HELP_SECTION:-main-screen} ]"' )

if [ -n "${HAS_REFRESH}" ] ; then
  fuzzy_default_options+=(
    "--bind" '"alt-l:execute[ /bin/zlogtail -l err,warn -F user,daemon -c ]+refresh-preview"'
    "--bind" '"ctrl-l:execute[ /bin/zlogtail -l err,warn -F user,daemon -c ]+refresh-preview"'
    "--bind" '"ctrl-alt-l:execute[ /bin/zlogtail -l err,warn -F user,daemon -c ]+refresh-preview"'
  )
else
  fuzzy_default_options+=(
    "--bind" '"alt-l:execute[ /bin/zlogtail -l err,warn -F user,daemon -c ]"'
    "--bind" '"ctrl-l:execute[ /bin/zlogtail -l err,warn -F user,daemon -c ]"'
    "--bind" '"ctrl-alt-l:execute[ /bin/zlogtail -l err,warn -F user,daemon -c ]"'
  )
fi

if command -v fzf >/dev/null 2>&1; then
  zdebug "using fzf for pager"
  export FUZZYSEL=fzf
  export PREVIEW_HEIGHT=2
  export FZF_DEFAULT_OPTS="--cycle ${fuzzy_default_options[*]}"
elif command -v sk >/dev/null 2>&1; then
  zdebug "using sk for pager"
  export FUZZYSEL=sk
  export PREVIEW_HEIGHT=3
  export SKIM_DEFAULT_OPTIONS="${fuzzy_default_options[*]}"
else
  # The menu needs a fuzzy menu
  color=red delay=10 timed_prompt \
    "No fuzzy menu (fzf or sk) is available"
    "Dropping to an emergency shell"
  tput clear
  tput cnorm
  exit 1
fi

# Clear screen before a possible password prompt
tput clear

BE_SELECTED=0

while true; do
  tput civis

  if [ "${BE_SELECTED}" -eq 0 ]; then
    # Populate the BE list, load any keys as necessary
    # If no BEs were found, remove the empty environment file
    populate_be_list "${BASE}/bootenvs" || rm -f "${BASE}/bootenvs"

    bootenv="$( draw_be "${BASE}/bootenvs" )"
    ret=$?

    if [ "${ret}" -eq 130 ]; then
      # No BEs were found, so print a warning and drop to the emergency shell
      color=red delay=10 timed_prompt \
        "No boot environments with kernels found" \
        "Dropping to an emergency shell to allow recovery attempts"
      tput clear
      tput cnorm
      exit 1
    elif [ "${ret}" -ne 0 ]; then
      # Esc was pressed
      continue
    fi

    # A selection was made, so split "key,selected_be" pair
    # shellcheck disable=SC2162
    IFS=, read key selected_be <<<"${bootenv}"
    zdebug "selected key: ${key}"
  fi

  # At this point, either a boot proceeds or a menu will be drawn fresh
  BE_SELECTED=0

  case "${key}" in
    "enter")
      if ! kexec_kernel "$( select_kernel "${selected_be}" )"; then
        zdebug "kexec failed for ${selected_be}"
        continue
      fi
      # Should never be reached, but just in case...
      exit
      ;;
    "mod-k")
      selection="$( draw_kernel "${selected_be}" )" || continue

      # shellcheck disable=SC2162
      IFS=, read subkey selected_kernel <<< "${selection}"
      zdebug "selected kernel: ${selected_kernel}"

      # shellcheck disable=SC2034
      IFS=' ' read -r fs kpath initrd <<< "${selected_kernel}"

      case "${subkey}" in
        "enter")
          if ! kexec_kernel "${selected_kernel}"; then
            zdebug "kexec failed for ${selected_kernel}"
            continue
          fi
          exit
          ;;
        "mod-d")
          set_default_kernel "${fs}" "${kpath}"
          ;;
        "mod-u")
          set_default_kernel "${fs}"
          ;;
      esac
      ;;
    "mod-p")
      selection="$( draw_pool_status )" || continue

      # shellcheck disable=SC2162
      IFS=, read subkey selected_pool <<< "${selection}"
      zdebug "selected pool: ${selected_pool}"

      case "${subkey}" in
        "enter")
          continue
          ;;
        "mod-r")
          rewind_checkpoint "${selected_pool}"
          ;;
      esac
      ;;
    "mod-d")
      set_default_env "${selected_be}"
      echo "${BOOTFS}" > "${BASE}/bootfs"
      ;;
    "mod-s")
      selection="$( draw_snapshots "${selected_be}" )" || continue

      # shellcheck disable=SC2162
      IFS=, read subkey selected_snap <<< "${selection}"
      zdebug "selected snapshot: ${selected_snap}"

      # Parent of the selected dataset, must be nonempty
      parent_ds="${selected_snap%/*}"
      [ -n "$parent_ds" ] || continue

      tput clear
      tput cnorm

      case "${subkey}" in
        "mod-i")
          zfs_chroot "${selected_snap}"
          BE_SELECTED=1
          continue
        ;;
        "mod-o")
          change_sort
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
            zerror "Insufficient space for duplication, ${parent_ds}' has ${avail_space} free but needs ${be_size}"
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

      while true; do
        echo -e "\nNew boot environment name (leave blank to abort)"
        new_be="$( /libexec/zfsbootmenu-input "${pre_populated}" )"

        [ -n "${new_be}" ] || break

        valid_name=$( echo "${new_be}" | tr -c -d 'a-zA-Z0-9-_.:' )
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
        "mod-x")
          clone_snapshot "${selected_snap}" "${clone_target}"
          ;;
        "mod-c")
          clone_snapshot "${selected_snap}" "${clone_target}" "nopromote"
          ;;
      esac
      ;;
    "mod-r")
      tput cnorm
      tput clear
      break
      ;;
    "mod-w")
      pool="${selected_be%%/*}"

      # This will make all keys in the pool unavailable, but populate_be_list
      # should reload the missing keys in the next iteration, so why unlock here?
      if is_writable "${pool}"; then
        export_pool "${pool}" && read_write='' import_pool "${pool}"
      else
        set_rw_pool "${pool}"
      fi

      # Clear the screen ahead of a potential password prompt from populate_be_list
      tput clear
      tput cnorm
      ;;
    "mod-e")
      tput clear
      tput cnorm

      echo ""
      /libexec/zfsbootmenu-preview "${selected_be}" "${BOOTFS}"

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
    "mod-i")
      zfs_chroot "${selected_be}"
    ;;
    "mod-o")
      change_sort
    ;;
  esac
done
