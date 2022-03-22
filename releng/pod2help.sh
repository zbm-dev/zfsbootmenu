#!/bin/bash
set -e

td="zfsbootmenu/help-files"
for size in 52 92 132 ; do
  rm "${td}/${size}"/* >/dev/null 2>&1 || /bin/true
  for pod in docs/pod/online/*.pod docs/pod/zfsbootmenu.7.pod; do
    [ -d "${td}/${size}" ] || mkdir -p "${td}/${size}"
    file="$( basename "${pod}" )"
    pod2text -c -i 0 -l -w "${size}" "${pod}" > "${td}/${size}/${file}"
  done
done
