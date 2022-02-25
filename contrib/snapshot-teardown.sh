#!/bin/bash

## A simple teardown hook to take a clean snapshot of the boot environment
## prior to launching the new kernel. This requires that your pool be read-write
## and will always export it.
##
## To use, put this script somewhere, make sure it is executable, and add the
## path to the `zfsbootmenu_teardown` space-separated list with, e.g.,
##
##     zfsbootmenu_teardown+=" <path to script> "
##
## in a dracut.conf(5) file inside the directory specified for the option
## `Global.DracutConfDir` in the ZFSBootMenu `config.yaml`.

# exit early if we're missing our env var
[ -n "${ZBM_SELECTED_BE}" ] || exit

for src in /lib/zfsbootmenu-core.sh /lib/kmsg-log-lib.sh ; do
  # shellcheck disable=SC1090
  source "${src}" || exit
done

zpool="${ZBM_SELECTED_BE%%/*}"

if ! zpool list -H -o name "${zpool}" >/dev/null 2>&1 ; then
  read_write=true import_pool "${zpool}"
else
  set_rw_pool "${zpool}"
fi

printf -v snapshot "${ZBM_SELECTED_BE}@preboot-%(%Y-%m-%d-%H%M%S)T"
zfs snapshot "${snapshot}" 
export_pool "${zpool}"
