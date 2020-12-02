#!/bin/bash
TMP="$( mktemp -d )"
# shellcheck disable=SC2064
trap "sudo umount '${TMP}'" EXIT

cp ../../etc/zfsbootmenu/config.yaml spaced.yaml
yq-go w -i spaced.yaml Global.ManageImages true
yq-go w -i spaced.yaml Global.BootMountPoint "${TMP}"
yq-go w -i spaced.yaml Components.ImageDir "${TMP}"
yq-go w -i spaced.yaml Components.Versions false
yq-go w -i spaced.yaml EFI.ImageDir "${TMP}"

sudo mount tmpfs -t tmpfs -o size=10M "${TMP}"
echo ""
echo "Unversioned component build, not enough space"
echo ""
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
sudo umount "${TMP}"

sudo mount tmpfs -t tmpfs -o size=60M "${TMP}"
echo ""
echo "Unversioned component build, enough space"
echo ""
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
sudo umount "${TMP}"

sudo mount tmpfs -t tmpfs -o size=60M "${TMP}"
echo ""
echo "Unversioned component build, with backup, not enough space"
echo ""
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
sudo umount "${TMP}"

sudo mount tmpfs -t tmpfs -o size=120M "${TMP}"
echo ""
echo "Unversioned component build, with backup, enough space"
echo ""
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
sudo umount "${TMP}"

yq-go w -i spaced.yaml Components.Versions 2
sudo mount tmpfs -t tmpfs -o size=10M "${TMP}"
echo ""
echo "Versioned component build, not enough space"
echo ""
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
sudo umount "${TMP}"

sudo mount tmpfs -t tmpfs -o size=60M "${TMP}"
echo ""
echo "Versioned component build, enough space"
echo ""
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
sudo umount "${TMP}"

sudo mount tmpfs -t tmpfs -o size=60M "${TMP}"
echo ""
echo "Versioned component build, twice, not enough space"
echo ""
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
sudo umount "${TMP}"

sudo mount tmpfs -t tmpfs -o size=120M "${TMP}"
echo ""
echo "Versioned component build, twice, enough space"
echo ""
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
sudo umount "${TMP}"

yq-go w -i spaced.yaml Components.Enabled false
yq-go w -i spaced.yaml EFI.Enabled true

sudo mount tmpfs -t tmpfs -o size=10M "${TMP}"
echo ""
echo "Unversioned UEFI build, not enough space"
echo ""
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
sudo umount "${TMP}"

sudo mount tmpfs -t tmpfs -o size=60M "${TMP}"
echo ""
echo "Unversioned UEFI build, enough space"
echo ""
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
sudo umount "${TMP}"

sudo mount tmpfs -t tmpfs -o size=60M "${TMP}"
echo ""
echo "Unversioned UEFI build, with backup, not enough space"
echo ""
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
sudo umount "${TMP}"

sudo mount tmpfs -t tmpfs -o size=120M "${TMP}"
echo ""
echo "Unversioned UEFI build, with backup, enough space"
echo ""
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
sudo umount "${TMP}"

yq-go w -i spaced.yaml EFI.Versions 2
sudo mount tmpfs -t tmpfs -o size=10M "${TMP}"
echo ""
echo "Versioned UEFI build, not enough space"
echo ""
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
sudo umount "${TMP}"

sudo mount tmpfs -t tmpfs -o size=60M "${TMP}"
echo ""
echo "Versioned UEFI build, enough space"
echo ""
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
sudo umount "${TMP}"

sudo mount tmpfs -t tmpfs -o size=60M "${TMP}"
echo ""
echo "Versioned UEFI build, twice, not enough space"
echo ""
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
sudo umount "${TMP}"

sudo mount tmpfs -t tmpfs -o size=120M "${TMP}"
echo ""
echo "Versioned UEFI build, twice, enough space"
echo ""
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
../../bin/generate-zbm -c spaced.yaml
ls -lah "${TMP}"
sudo umount "${TMP}"
