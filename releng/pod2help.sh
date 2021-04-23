#!/bin/bash

td="90zfsbootmenu/help-files"
for pod in pod/online/*.pod pod/zfsbootmenu.7.pod; do
  for size in 54 94 134 ; do
    [ -d "${td}/${size}" ] || mkdir -p "${td}/${size}"
    file="$( basename "${pod}" )"
    pod2text -c -i 0 -l -w "${size}" "${pod}" > "${td}/${size}/${file}"
  done
done
