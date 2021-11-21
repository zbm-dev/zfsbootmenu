#!/bin/bash

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
