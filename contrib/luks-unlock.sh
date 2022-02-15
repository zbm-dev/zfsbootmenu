#!/bin/bash

## This early-setup hook finds a LUKS volume by looking for a partition with
## label "KEYSTORE". (Partition labels are supported on GPT and a few obsolete
## disklabel formats; see the "name" command in parted(8) for details.)
##
## If a KEYSTORE partition is found, the hook attempts repeatedly to unlock and
## mount the encrypted volume (read-only) at /etc/zfs/keys. If successful, this
## will allow ZFSBootMenu to automatically unlock any ZFS datasets that define
## the ZFS property
##
##     keylocation=file:///etc/zfs/keys
##
## If the partition cannot be found, does not appear to be a LUKS volume or has
## already been activated, the hook will terminate and allow ZFSBootMenu to
## proceed with its ordinary startup process. Once the hook begins the unlock
## loop, it will not terminate until either the volume is successfully unlocked
## or the user presses Ctrl-C to abandon the attempts. After every failed
## unlock cycle, an emergency shell will be invoked to allow manual
## intervention; type `exit` in the shell to continue the unlock loop.
##
## Because this script is intended to provide unlock keys *before* ZFSBootMenu
## imports ZFS pools, it should be run as an early hook. To install, put this
## script somewhere, make sure it is executable, and add the path to the
## `zfsbootmenu_early_setup` space-separated list with, e.g.,
##
##     zfsbootmenu_early_setup+=" <path to script> "
##
## in a dracut.conf(5) file inside the directory specified for the option
## `Global.DracutConfDir` in the ZFSBootMenu `config.yaml`.

sources=(
  /lib/profiling-lib.sh
  /etc/zfsbootmenu.conf
  /lib/zfsbootmenu-core.sh
  /lib/kmsg-log-lib.sh
  /etc/profile
)

for src in "${sources[@]}"; do
  # shellcheck disable=SC1090
  if ! source "${src}" > /dev/null 2>&1 ; then
    echo -e "\033[0;31mWARNING: ${src} was not sourced; unable to proceed\033[0m"
    exit 1
  fi
done

unset src sources

luks="/dev/disk/by-partlabel/KEYSTORE"
dm="/dev/mapper/KEYSTORE"

if [ ! -b "${luks}" ] ; then
  zinfo "keystore device ${luks} does not exist"
  exit
fi

if ! cryptsetup isLuks ${luks} >/dev/null 2>&1 ; then
  zwarn "keystore device ${luks} missing LUKS partition header"
  exit
fi

if cryptsetup status "${dm}" >/dev/null 2>&1 ; then
  zinfo "${dm} already active, not continuing"
  exit
fi

header="$( center_string "[CTRL-C] cancel luksOpen attempts" )"

while true; do
  tput clear
  colorize red "${header}\n\n"

  cryptsetup --tries=5 luksOpen "${luks}" KEYSTORE
  ret=$?

  # successfully entered a passphrase
  if [ "${ret}" -eq 0 ] ; then
    mkdir -p /etc/zfs/keys
    mount -r "${dm}" /etc/zfs/keys
    zdebug "$(
      cryptsetup status "${dm}"
      mount | grep KEYSTORE
    )"
    exit
  fi

  # ctrl-c'd the process
  if [ "${ret}" -eq 1 ] ; then
    zdebug "canceled luksOpen attempts via SIGINT"
    exit
  fi

  # failed all password attempts
  if [ "${ret}" -eq 2 ] ; then
    if timed_prompt -e "emergency shell" \
      -r "continue unlock attempts" \
      -p "Continuing in %0.2d seconds" ; then
        continue
    else
      emergency_shell "Unable to unlock LUKS partition"
    fi
  fi
done
