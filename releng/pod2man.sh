#!/bin/sh
set -e 

release="${1?ERROR: no release version specified}"

MANDIR="docs/man"
PODDIR="docs/pod"

# Generate man pages from pod documentation
zbmconfig="${PODDIR}/generate-zbm.5.pod"
zbmsystem="${PODDIR}/zfsbootmenu.7.pod"
zbmkcl="${PODDIR}/zbm-kcl.8.pod"
zbmefikcl="${PODDIR}/zbm-efi-kcl.8.pod"
genzbm="bin/generate-zbm"

for src in "${zbmconfig}" "${zbmsystem}" "${zbmkcl}" "${zbmefikcl}" "${genzbm}"; do
	if [ ! -r "${src}" ]; then
		echo "ERROR: POD source '${src}' does not exist"
		exit 1
	fi
done

if [ ! -d "${MANDIR}" ]; then
	echo "ERROR: '${MANDIR}' directory does not exist in CWD"
	exit 1
fi

pod2man "${zbmconfig}" -c "config.yaml" \
  -r "${release}" -s 5 -n generate-zbm > "${MANDIR}/generate-zbm.5"

pod2man "${zbmsystem}" -c "ZFSBootMenu" \
  -r "${release}" -s 7 -n zfsbootmenu > "${MANDIR}/zfsbootmenu.7"

pod2man "${genzbm}" -c "generate-zbm" \
  -r "${release}" -s 8 -n generate-zbm > "${MANDIR}/generate-zbm.8"

pod2man "${zbmkcl}" -c "zbm-kcl" \
  -r "${release}" -s 8 -n zbm-kcl > "${MANDIR}/zbm-kcl.8"

pod2man "${zbmefikcl}" -c "zbm-efi-kcl" \
  -r "${release}" -s 8 -n zbm-efi-kcl > "${MANDIR}/zbm-efi-kcl.8"
