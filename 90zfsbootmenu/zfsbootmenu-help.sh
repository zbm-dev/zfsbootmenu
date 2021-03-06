#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# shellcheck disable=SC1091
[ -r /lib/zfsbootmenu-lib.sh ] && source /lib/zfsbootmenu-lib.sh

# zfsbootmenu-help invokes itself, so the value of $WIDTH depends
# on if $0 is launching fzf/sk (-L) or is being launched inside
# fzf/sk (-s).
WIDTH="$( tput cols )"
PREVIEW_SIZE="$(( WIDTH - 26 ))"
[ ${PREVIEW_SIZE} -lt 10 ] && PREVIEW_SIZE=10

[ -z "${FUZZYSEL}" ] && FUZZYSEL="fzf"

mod_header() {
  local key="$1"
  local subject="$2"

  [ -n "${subject}" ] && echo -e "$( colorize lightblue "${subject}" )"
  [ -n "${key}" ] && echo -e -n "$( colorize green "[CTRL+${key}]" ) or $( colorize green "[ALT+${key}]" )"
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
    --preview-window="right:${PREVIEW_SIZE}:wrap" \
    --header="$( colorize green "[ESC]" ) $( colorize lightblue "back" )" \
    --tac \
    --color='border:6'
}

# shellcheck disable=SC2034
read -r -d '' MAIN <<EOF
$( colorize magenta "$( center_string "Main Menu")" )
$( colorize lightblue "boot" )
$( colorize green "[ENTER]" )

Boot the selected boot environment, with the listed kernel and kernel command line visible at the top of the screen.


$( mod_header K "kernels" )

Access a list of kernels available in the boot environment.


$( mod_header S "snapshots" )

Access a list of snapshots of the selected boot environment. New boot environments can be created here.


$( mod_header D "set bootfs" )

Set the selected boot environment as the default for the pool.

The operation will fail gracefully if the pool can not be set $( colorize red "read/write" ).


$( mod_header E "edit kcl" )

Temporarily edit the kernel command line that will be used to boot the chosen kernel in the selected boot environment. This change does not persist across reboots.


$( mod_header P "pool status" )

View the health and status of each imported pool.


$( mod_header R "recovery shell" )

Execute a Bash shell with minimal tooling, enabling system maintenance.


$( mod_header I "interactive chroot" )

Enter a chroot of the selected boot environment. The boot environment is mounted $( colorize red "read/write") if the zpool is imported $( colorize red "read/write" ).


$( mod_header W "import read/write" )

If possible, the pool behind the selected boot environment is exported and then re-imported in $( colorize red "read/write") mode.

This is not possible if any of the following conditions are met:

 $( colorize red "*") The version of ZFS in ZFSBootMenu has detected unsupported pool features, due to an upgraded pool.
 $( colorize red "*") The system has an active $( colorize red "resume") image, indicating that the pool is currently in use.

Upon successful re-import in $( colorize red "read/write") mode, each of the boot environments on this pool will be highlighted in $( colorize red "red") at the top of the screen.


$( mod_header O "sort order" )

Cycle the sorting key through the following list:

     $( colorize orange "name") Use the filesystem or snapshot name
 $( colorize orange "creation") Use the filesystem or snapshot creation time
     $( colorize orange "used") Use the filesystem or snapshot size

The default sort key is $( colorize orange "name") . 


$( mod_header L "view logs" )

View logs, as indicated by $( colorize yellow "[!]" ) (warning) and $( colorize red "[!]" ) (error) in the upper left corner.

EOF
SECTIONS+=("MAIN Main Menu")

# shellcheck disable=SC2034
read -r -d '' SNAPSHOT <<EOF
$( colorize magenta "$( center_string "Snapshot Management")" )
$( colorize lightblue "duplicate" )
$( colorize green "[ENTER]" )

Creation method: $( colorize red "zfs send | zfs recv" )

This creates a boot environment that does not depend on any other snapshots, allowing it to be destroyed at will. The new boot environment will immediately consume space on the pool equal to the $( colorize lightgray "REFER" ) value of the snapshot.

A duplicated boot environment is commonly used if you need a new boot environment without any associated snapshots.

The operation will fail gracefully if the pool can not be set $( colorize red "read/write" ).

If $( colorize red "mbuffer" ) is available, it is used to provide feedback.


$( mod_header X "clone and promote" )

Creation method: $( colorize red "zfs clone" ) , $( colorize red "zfs promote" )

This creates a boot environment that is not dependent on the origin snapshot, allowing you to destroy the file system that the clone was created from. A cloned and promoted boot environment is commonly used when you've done an upgrade but want to preserve historical snapshots.

The operation will fail gracefully if the pool can not be set $( colorize red "read/write" ).


$( mod_header C "clone" )

Creation method: $( colorize red "zfs clone" )

This creates a boot environment from a snapshot with out modifying snapshot inheritence. A cloned boot environment is commonly used if you need to boot a previous system state for a short time and then discard the environment.

The operation will fail gracefully if the pool can not be set $( colorize red "read/write" ).


$( mod_header D "diff" )

Compare the differences between the selected snapshot and the current state of the boot environment.

The operation will fail gracefully if the pool can not be set $( colorize red "read/write" ).


$( mod_header I "interactive chroot" )

Enter a chroot of the selected boot environment snapshot. The snapshot is always mounted read-only.


$( mod_header O "sort order" )

Cycle the sorting key through the following list:

     $( colorize orange "name") Use the filesystem or snapshot name
 $( colorize orange "creation") Use the filesystem or snapshot creation time
     $( colorize orange "used") Use the filesystem or snapshot size

The default sort key is $( colorize orange "name") . 


$( mod_header L "view logs" )

View logs, as indicated by $( colorize yellow "[!]" ) (warning) and $( colorize red "[!]" ) (error) in the upper left corner.

EOF
SECTIONS+=("SNAPSHOT Snapshot Management")

# shellcheck disable=SC2034
read -r -d '' KERNEL <<EOF
$( colorize magenta "$( center_string "Kernel Management")" )
$( colorize lightblue "boot" )
$( colorize green "[ENTER]" )

Immediately boot the chosen kernel in the selected boot environment, with the kernel command line shown at the top of the screen.


$( mod_header D "set default" )

Set the selected kernel as the default for the boot environment.

The ZFS property $( colorize green "org.zfsbootmenu:kernel" ) is used to store the default kernel for the boot environment.

The operation will fail gracefully if the pool can not be set $( colorize red "read/write" ).


$( mod_header L "view logs" )

View logs, as indicated by $( colorize yellow "[!]" ) (warning) and $( colorize red "[!]" ) (error) in the upper left corner.

EOF
SECTIONS+=("KERNEL Kernel Management")

# shellcheck disable=SC2034
read -r -d '' DIFF <<EOF
$( colorize magenta "$( center_string "Diff Viewer")" )
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
$( colorize magenta "$( center_string "ZPOOL Health")" )
$( mod_header R "rewind checkpoint" )

If a pool checkpoint is available, the selected pool is exported and then imported with the $( colorize red "--rewind-to-checkpoint" ) flag set.

The operation will fail gracefully if the pool can not be set $( colorize red "read/write" ).


$( mod_header L "view logs" )

View logs, as indicated by $( colorize yellow "[!]" ) (warning) and $( colorize red "[!]" ) (error) in the upper left corner.

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
      echo "${!section}" | fold -s -w "${WIDTH}"
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
