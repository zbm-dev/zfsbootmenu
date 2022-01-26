#!/bin/sh
set -e 

release="${1?ERROR: no release version specified}"

# Generate man pages from pod documentation
zbmconfig="pod/generate-zbm.5.pod"
zbmsystem="pod/zfsbootmenu.7.pod"
zbmkcl="pod/zbm-kcl.8.pod"
genzbm="bin/generate-zbm"

for src in "${zbmconfig}" "${zbmsystem}" "${zbmkcl}" "${genzbm}"; do
	if [ ! -r "${src}" ]; then
		echo "ERROR: POD source '${src}' does not exist"
		exit 1
	fi
done

if [ ! -d man ]; then
	echo "ERROR: 'man' directory does not exist in CWD"
	exit 1
fi

pod2man "${zbmconfig}" -c "config.yaml" \
  -r "${release}" -s 5 -n generate-zbm > man/generate-zbm.5

pod2man "${zbmsystem}" -c "ZFSBootMenu" \
  -r "${release}" -s 7 -n zfsbootmenu > man/zfsbootmenu.7

pod2man "${genzbm}" -c "generate-zbm" \
  -r "${release}" -s 8 -n generate-zbm > man/generate-zbm.8

pod2man "${zbmkcl}" -c "zbm-kcl" \
  -r "${release}" -s 8 -n zbm-kcl > man/zbm-kcl.8
