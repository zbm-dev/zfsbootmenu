#!/bin/bash

## This script can be used by generate-zbm to keep two or more ESPs in sync 
## after an EFI is built. Place the script in the directory defined by:
##
##   Global.PostHooksDir
##
## Ensure the file is executable. Adjust the ESPS variable to include
## the correct disks / partitions for your BACKUP EFI partitions. Do NOT include
## the primary/master ESP. Your master EFI mountpoint will be read, and used
## as the base for copying files to your other partitions.
## 
## Only files with `zfsbootmenu` in the name are copied to / deleted from
## the backup ESPs. It will not manage any other files for you.
## 
## This hook relies on yq-go and rsync.


cleanup() {
  if [ -n "${ESP_MNT}" ]; then
    mountpoint -q "${ESP_MNT}" && umount -R "${ESP_MNT}"
    [ -d "${ESP_MNT}" ] && rmdir "${ESP_MNT}"
  fi
}

ESPS=(
  "/dev/sdb1"
  "/dev/sdc1"
  "/dev/sdd1"
)

BMP="$( yq-go eval ".Global.BootMountPoint" /etc/zfsbootmenu/config.yaml )"
if [ -z "${BMP}" ]; then
  echo "Unable to determine BootMountPoint"
  exit 1
fi

IMG_DIR="$( yq-go eval ".EFI.ImageDir" /etc/zfsbootmenu/config.yaml )"
if [ -z "${IMG_DIR}" ]; then
  echo "Unable to determine ImageDir"
  exit 1
fi

IMG_REL="${IMG_DIR#"${BMP}"}"

mount "${BMP}"

if ! ESP_MNT="$( mktemp -d )"; then
  echo "Unable to create temporary mountpoint"
  exit
fi

trap cleanup EXIT INT TERM

for ESP in "${ESPS[@]}"; do
  if ! mount "${ESP}" "${ESP_MNT}" ; then
    echo "Unable to mount ${ESP} at ${ESP_MNT}"
    continue
  fi

  mkdir -p "${ESP_MNT}${IMG_REL}"
  rsync --delete-after -avpP --include=zfsbootmenu\* --exclude=\* "${IMG_DIR}/" "${ESP_MNT}${IMG_REL}/"

  if ! umount "${ESP_MNT}" ; then
    echo "Unable to unmount ${ESP_MNT}"
    exit 1
  fi
done
