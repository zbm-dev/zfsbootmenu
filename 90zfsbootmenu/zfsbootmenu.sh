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

mkdir -p "${BASE}"

while [ ! -e "${BASE}/initialized" ]; do
  if ! delay=5 prompt="Press [ESC] to cancel" timed_prompt "Waiting for ZFSBootMenu initialization"; then
    zdebug "exited while waiting for initialization"
    tput cnorm
    tput clear
    exit
  fi
done

[ -e "${BASE}/active" ] && takeover

# If the takeover fails for some reason, spin until it ends
while [ -e "${BASE}/active" ]; do
  if ! delay=1 prompt="Press [ESC] to cancel" timed_prompt "Waiting for other ZFSBootMenu instance to terminate"; then
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
trap "zdebug 'exiting via USR1 signal' ; tput clear ; exit 0" SIGUSR1
trap '' SIGINT

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

# Override control_term if executing over SSH
# shellcheck disable=SC2034
[ -n "${SSH_TTY}" ] && control_term="${SSH_TTY}"

# Single quote the help binds so that $HELP_SECTION expands when the key combo
# is pressed, and not now.
# Double quote the zlogtail lines so that they expand immediately

# shellcheck disable=SC2016
fuzzy_default_options=(
  "--ansi" "--no-clear" "--cycle" "--color=16"
  "--layout=reverse-list" "--inline-info" "--tac"
  "--bind" '"alt-h:execute[ /libexec/zfsbootmenu-help -L ${HELP_SECTION:-main-screen} ]"'
  "--bind" '"ctrl-h:execute[ /libexec/zfsbootmenu-help -L ${HELP_SECTION:-main-screen} ]"'
  "--bind" '"ctrl-alt-h:execute[ /libexec/zfsbootmenu-help -L ${HELP_SECTION:-main-screen} ]"'
  "--bind" "\"alt-l:execute[ /bin/zlogtail ]${HAS_REFRESH:++refresh-preview}\""
  "--bind" "\"ctrl-l:execute[ /bin/zlogtail ]${HAS_REFRESH:++refresh-preview}\""
  "--bind" "\"ctrl-alt-l:execute[ /bin/zlogtail ]${HAS_REFRESH:++refresh-preview}\""
)

# shellcheck disable=SC2016,SC2086
if [ ${loglevel:-4} -eq 7 ] ; then
  fuzzy_default_options+=(
    "--bind" '"alt-t:execute[ /sbin/ztrace > ${control_term} ]"'
    "--bind" '"ctrl-t:execute[ /sbin/ztrace > ${control_term} ]"'
    "--bind" '"ctrl-alt-t:execute[ /sbin/ztrace > ${control_term} ]"'
    "--bind" '"f12:execute[ /libexec/zfunc emergency_shell \"debugging shell\" > ${control_term} ]"'
  )
fi

if command -v fzf >/dev/null 2>&1; then
  export FUZZYSEL=fzf
  export PREVIEW_HEIGHT=2
  export FZF_DEFAULT_OPTS="${fuzzy_default_options[*]}"
else
  # The menu needs a fuzzy menu
  color=red delay=10 timed_prompt \
    "fzf is not available"
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

      # two snapshots were potentially returned - discard the second
      selected_snap="${selected_snap%,*}"
      zdebug "selected snapshot: ${selected_snap}"

      if is_snapshot "${selected_snap}" ; then
        case "${subkey}" in
          "mod-j")
            zfs_chroot "${selected_snap}"
            BE_SELECTED=1
            continue
          ;;
          "mod-o")
            change_sort
            BE_SELECTED=1
            continue
          ;;
          *)
            snapshot_dispatcher "${selected_snap}" "${subkey}"
            continue
          ;;
        esac
      else
        case "${subkey}" in
          "mod-n")
            snapshot_dispatcher "${selected_be}" "${subkey}"
            continue
          ;;
          *)
            BE_SELECTED=1
            continue
          ;;
        esac
      fi
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
        set_ro_pool "${pool}"
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
    "mod-j")
      zfs_chroot "${selected_be}"
      ;;
    "mod-o")
      change_sort
      ;;
  esac
done
