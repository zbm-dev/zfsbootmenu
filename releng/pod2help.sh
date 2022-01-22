#!/bin/bash
set -e

td="zfsbootmenu/help-files"
for size in 54 94 134 ; do
  rm "${td}/${size}"/*
  for pod in pod/online/*.pod pod/zfsbootmenu.7.pod; do
    [ -d "${td}/${size}" ] || mkdir -p "${td}/${size}"
    file="$( basename "${pod}" )"
    pod2text -c -i 0 -l -w "${size}" "${pod}" > "${td}/${size}/${file}"
  done
done
