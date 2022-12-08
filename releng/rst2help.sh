#!/bin/bash
set -e

td="zfsbootmenu/help-files"
for size in 52 92 132 ; do
  rm "${td}/${size}"/* >/dev/null 2>&1 || /bin/true
  for doc in docs/online/*.rst docs/man/zfsbootmenu.7.rst; do
    [ -d "${td}/${size}" ] || mkdir -p "${td}/${size}"
    file="$( basename "${doc}" )"
    echo "Converting ${doc}"
    COLUMNS="${size}" rst2ansi "${doc}" | sed '1s/ - \(.*\)$/\n\n\o033\[1m\1\o033\[0m/;s/\[3m/\[33m/g' > "${td}/${size}/${file}"
  done
done
