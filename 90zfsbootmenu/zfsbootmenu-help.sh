#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab
WIDTH="$( tput cols )"
PREVIEW_SIZE=$(( WIDTH - 26 ))

[ -z "${FUZZYSEL}" ] && FUZZYSEL="fzf"

center() {
  printf "%*s" $(( (${#1} + WIDTH ) / 2)) "${1}"
}

colorize() {
  color="${1}"
  shift
  case "${color}" in
    black) echo -e -n '\033[0;30m' ;;
    red) echo -e -n '\033[0;31m' ;;
    green) echo -e -n '\033[0;32m' ;;
    orange) echo -e -n '\033[0;33m' ;;
    blue) echo -e -n '\033[0;34m' ;;
    magenta) echo -e -n '\033[0;35m' ;;
    cyan) echo -e -n '\033[0;36m' ;;
    lightgray) echo -e -n '\033[0;37m' ;;
    darkgray) echo -e -n '\033[1;30m' ;;
    lightred) echo -e -n '\033[1;31m' ;;
    lightgreen) echo -e -n '\033[1;32m' ;;
    yellow) echo -e -n '\033[1;33m' ;;
    lightblue) echo -e -n '\033[1;34m' ;;
    lightmagenta) echo -e -n '\033[1;35m' ;;
    lightcyan) echo -e -n '\033[1;36m' ;;
    white) echo -e -n '\033[1;37m' ;;
    *) echo -e -n '\033[0m' ;;
  esac
  echo -e -n "$@"
  echo -e -n '\033[0m'
}

help_pager() {
  WANTED="${1}"

  SORTED=()
  for SECTION in "${SECTIONS[@]}"; do
    if ! [[ $SECTION =~ ${WANTED} ]]; then
      SORTED+=("${SECTION}")
    else
      FINAL="${SECTION}"
    fi
    done
  SORTED+=("${FINAL}")

  printf '%s\n' "${SORTED[@]}" | ${FUZZYSEL} \
    --prompt 'Topic >' \
    --with-nth=2.. \
    --bind pgup:preview-up,pgdn:preview-down \
    --preview="$0 -s {1}" \
    --preview-window="right:${PREVIEW_SIZE}:sharp:wrap" \
    --tac \
    --color='border:6'
}

# shellcheck disable=SC2034
read -r -d '' MAIN <<EOF
$( colorize magenta "$( center "Main Menu")" )
$( colorize lightblue "[ENTER] boot" )
Boot the selected boot environment, with the listed kernel and kernel command line visible at the top of the screen.

$( colorize lightblue "[ALT+K] kernel" )
Access a list of kernels available in the boot environment.

$( colorize lightblue "[ALT+D] set bootfs" )
Set the selected boot environment as the default for the pool.

The operation will gracefully fail if the pool can not be set $( colorize red "read/write" ).

$( colorize lightblue "[ALT+S] snapshots" )
Access a list of snapshots of the selected boot environment. New boot environments can be created here.

$( colorize lightblue "[ALT+C] cmdline" )
Temporarily edit the kernel command line that will be used to boot the next kernel and boot environment. This change is not persisted between boots.

$( colorize lightblue "[ALT+P] Pool status" )
View the health and status of each imported pool.
EOF
SECTIONS+=("MAIN Main Menu")

# shellcheck disable=SC2034
read -r -d '' SNAPSHOT <<EOF
$( colorize magenta "$( center "Snapshot Management")" )
$( colorize lightblue "[ENTER] duplicate" )
Creation method: $( colorize red "zfs send | zfs recv" )

This creates a boot environment that does not depend on any other snapshots, allowing it to be destroyed at will. The new boot environment will immediately consume space on the pool equal to the $( colorize lightgray "REFER" ) value of the snapshot.

A duplicated boot environment is commonly used if you need a new boot environment without any associated snapshots.

The operation will gracefully fail if the pool can not be set $( colorize red "read/write" ).

If $( colorize red "mbuffer" ) is available, it is used to provide feedback.

$( colorize lightblue "[ALT+X] clone and promote" )
Creation method: $( colorize red "zfs clone" ) , $( colorize red "zfs promote" )

This creates a boot environment that is not dependent on the origin snapshot, allowing you to destroy the file system that the clone was created from. A cloned and promoted boot environment is commonly used when you've done an upgrade but want to preserve historical snapshots.

The operation will gracefully fail if the pool can not be set $( colorize red "read/write" ).

$( colorize lightblue "[ALT+C] clone" )
Creation method: $( colorize red "zfs clone" )

This creates a boot environment from a snapshot with out modifying snapshot inheritence. A cloned boot environment is commonly used if you need to boot a previous system state for a short time and then discard the environment.

The operation will gracefully fail if the pool can not be set $( colorize red "read/write" ).

$( colorize lightblue "[ALT+D] diff" )
Compare the differences between the selected snapshot and the current state of the boot environment.

The operation will gracefully fail if the pool can not be set $( colorize red "read/write" ).
EOF
SECTIONS+=("SNAPSHOT Snapshot Management")

# shellcheck disable=SC2034
read -r -d '' KERNEL <<EOF
$( colorize magenta "$( center "Kernel Management")" )
$( colorize lightblue "[ENTER] boot" )
Immediately boot the selected kernel in the boot environment, with the kernel command line shown at the top of the screen.

$( colorize lightblue "[ALT+D] set default" )
Set the selected kernel as the default for the boot environment.

The ZFS property $( colorize green "org.zfsbootmenu:kernel" ) is used to store the default kernel for the boot environment.

The operation will gracefully fail if the pool can not be set $( colorize red "read/write" ).

EOF
SECTIONS+=("KERNEL Kernel Management")

# shellcheck disable=SC2034
read -r -d '' DIFF <<EOF
$( colorize magenta "$( center "Diff Viewer")" )
$( colorize lightblue "Column 1 descriptions" )
 $( colorize orange "-") The path has been removed
 $( colorize orange "+") The path has been created
 $( colorize orange "M") The path has been modified
 $( colorize orange "R") The path has been renamed

$( colorize lightblue "Column 2 descriptions" )
 $( colorize orange "B") Block device
 $( colorize orange "C") Character device
 $( colorize orange "/") Directory
 $( colorize orange ">") Door
 $( colorize orange "|") Named pipe
 $( colorize orange "@") Symbolic link
 $( colorize orange "P") Event port
 $( colorize orange "=") Socket
 $( colorize orange "F") Regular file

EOF
SECTIONS+=("DIFF Diff Viewer")

# shellcheck disable=SC2034
read -r -d '' POOL <<EOF
$( colorize magenta "$( center "zpool Health")" )
$( colorize lightblue "[ALT+R] Rewind checkpoint" )
If a pool checkpoint is available, the selected pool is exported and then imported with $( colorize red "--rewind-to-checkpoint" ) set.

The operation will gracefully fail if the pool can not be set $( colorize red "read/write" ).
EOF
SECTIONS+=("POOL ZPOOL Health")

while getopts "lL:s:" opt; do
  case "${opt}" in
    l)
      printf '%s\n' "${SECTIONS[@]}"
      exit
      ;;
    L)
      help_pager "${OPTARG}"
      exit
      ;;
    s)
      section="${OPTARG}"
      echo "${!section}" | fold -s -w "${FZF_PREVIEW_COLUMNS}"
      exit
      ;;
    ?)
      exit
      ;;
    *)
      exit
      ;;
  esac
done

# No options detected, show the main help section
help_pager "MAIN"
