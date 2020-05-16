#!/bin/bash
# store current kernel log level
read -r printk < /proc/sys/kernel/printk
printk=${printk:0:1}

# Set it to 0
echo 0 > /proc/sys/kernel/printk

test -f /lib/zfsbootmenu-lib.sh && source /lib/zfsbootmenu-lib.sh
test -f zfsbootmenu-lib.sh && source zfsbootmenu-lib.sh

echo "Loading boot menu ..."
TERM=linux
tput reset

OLDIFS="$IFS"

export FZF_DEFAULT_OPTS="--layout=reverse-list --cycle \
  --inline-info --tac"

BASE="$( mktemp -d /tmp/zfs.XXXX )"

# I should probably just modprobe zfs right off the bat
modprobe zfs 2>/dev/null
udevadm settle

# Find all pools by name that are listed as ONLINE, then import them
response="$( find_online_pools )"
ret=$?

if [ $ret -gt 0 ]; then
  import_success=0
  IFS=',' read -a zpools <<<"${response}"
  for pool in "${zpools[@]}"; do
    import_pool ${pool}
    ret=$?
    if [ $ret -eq 0 ]; then
      import_success=1
    fi
  done
  if [ $import_success -ne 1 ]; then
    emergency_shell "unable to successfully import a pool"
  fi
else
  if [ $die_on_import_failure -eq 1 ]; then
    emergency_shell "no pools available to import"
    exit;
  fi
fi

# Prefer a specific pool when checking for a bootfs value
if [ "${root}" = "zfsbootmenu" ]; then
  pool=
else
  pool="${root}"
fi

# Attempt to find the bootfs property 
datasets="$( zpool list -H -o bootfs ${pool} )"
while read -r line; do
  if [ "${line}" = "-" ]; then
    BOOTFS=
  else
    BOOTFS="${line}"
    break
  fi
done <<<"${datasets}"

# If BOOTFS is not empty display the fast boot menu
fast_boot=0
if [[ ! -z "${BOOTFS}" ]]; then
  # Draw a countdown menu
  if [[ ${menu_timeout} -gt 0 ]]; then
    # Clear the screen
    tput civis
    HEIGHT=$(tput lines)
    WIDTH=$(tput cols)
    tput clear

    # Draw the line centered on the screen
    mes="[ENTER] to boot"
    x=$(( ($HEIGHT - 0) / 2 ))
    y=$(( ($WIDTH - ${#mes}) / 2 ))
    tput cup $x $y
    echo -n ${mes}

    # Draw the line centered on the screen
    mes="[ESC] boot menu"
    x=$(( $x + 1 ))
    y=$(( ($WIDTH - ${#mes}) / 2 ))
    tput cup $x $y
    echo -n ${mes}

    x=$(( $x + 1 ))
    tput cup $x $y

    IFS=''
    for (( i=${menu_timeout}; i>0; i--)); do
      mes="$( printf 'Booting %s in %0.2d seconds' ${BOOTFS} ${i} )"
      y=$(( ($WIDTH - ${#mes}) / 2 ))
      tput cup $x $y
      echo -ne "${mes}"

      # Wait 1 second for input
      read -s -N 1 -t 1 key
      # Escape key
      if [ "$key" = $'\e' ]; then
        break
      # Enter key
      elif [ "$key" = $'\x0a' ]; then
        fast_boot=1
        break
      fi
    done
    IFS="${OLDIFS}"
  elif [[ ${menu_timeout} -eq 0 ]]; then
    # Bypass the menu, immediately boot $BOOTFS
    fast_boot=1
  else
    # Make sure we bypass the other fastboot check
    i=1
  fi
  
  # Boot up if we timed out, or if the enter key was pressed
  if [[ ${fast_boot} -eq 1 || $i -eq 0 ]]; then
    if ! key_wrapper "${BOOTFS}" ; then
      emergency_shell "unable to load required key for ${BOOTFS}"
    fi

    # Generate a list of valid kernels for our bootfs
    if output=$( find_be_kernels "${BOOTFS}" ); then
      # Automatically select a kernel and boot it
      kexec_kernel "$( select_kernel "${BOOTFS}" )"
    fi
  fi
fi

##
# No automatic boot has taken place
# Find all ZFS filesystems on any pool that mount to /
# Load any keys as we come across them
# If any kernels were found in /boot for a BE, add that BE to our menu
##

# Find any filesystems that mount to /, see if there are any kernels present
for FS in $( zfs list -H -o name,mountpoint | grep -E "/$" | cut -f1 ); do
  if ! key_wrapper "${FS}" ; then
    continue
  fi

  # Check for kernels under the mountpoint, add to our BE list
  if output="$( find_be_kernels "${FS}" )" ; then
    echo ${FS} >> ${BASE}/env
  fi
done

if [ ! -f ${BASE}/env ]; then
  emergency_shell "no boot environments with kernels found"
fi

# This is the actual menuing system
BE_SELECTED=0
tput civis

while true; do
  if [ ${BE_SELECTED} -eq 0 ]; then
    bootenv="$( draw_be "${BASE}/env" )"
    ret=$?
    
    # key press
    # bootenv
    IFS=, read key selected_be <<<"${bootenv}"

    if [ $ret -eq 0 ]; then
      BE_SELECTED=1
    fi
  fi

  if [ ${BE_SELECTED} -eq 1 ]; then
    case "${key}" in
      "enter")
        kexec_kernel "$( select_kernel "${selected_be}" )"
        exit
        ;;
      "alt-k")
        selected_kernel="$( draw_kernel "${selected_be}" )"
        ret=$?

        if [ $ret -eq 130 ]; then
          BE_SELECTED=0 
        elif [ $ret -eq 0 ] ; then
          kexec_kernel "${selected_kernel}"
          exit
        fi
        ;;
      "alt-d")
        set_default_env "${selected_be}"
        BE_SELECTED=0
        ;;
      "alt-s")
        selected_snap="$( draw_snapshots "${selected_be}" )"
        ret=$?

        if [ $ret -eq 130 ]; then
          BE_SELECTED=0 
        elif [ $ret -eq 0 ] ; then
          clone_snapshot "${selected_snap}"
          BE_SELECTED=0 
        fi
        ;;
      "alt-a")
        selected_snap="$( draw_snapshots )"
        ret=$?

        if [ $ret -eq 130 ]; then
          BE_SELECTED=0 
        elif [ $ret -eq 0 ] ; then
          clone_snapshot "${selected_snap}"
          BE_SELECTED=0 
        fi
        ;;
      "alt-r")
        emergency_shell "alt-r invoked"
        BE_SELECTED=0
        ;;
      "alt-c")
        tput clear
        tput cnorm

        zfsbootmenu-preview.sh ${BASE} ${selected_be} ${BOOTFS}

        if [ -f "${BASE}/default_args" ]
        then
          ARGS="${BASE}/default_args"
        else
          ARGS="${BASE}/${selected_be}/default_args"
        fi

        while IFS= read -r line
        do
          def_args="${line}"
        done < "${ARGS}"
        echo -e "\nNew kernel command line"
        read -r -e -i "${def_args}" -p "> " cmdline
        if [ -n "${cmdline}" ]
        then
          echo "${cmdline}" > "${BASE}/default_args"
        fi
        BE_SELECTED=0
        tput civis
        ;;
    esac
  fi
done
