#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# shellcheck disable=SC1091
source /lib/kmsg-log-lib.sh >/dev/null 2>&1 || exit 1
source /lib/zfsbootmenu-lib.sh >/dev/null 2>&1 || exit 1

# First argument is the function name
# the rest are positional params
func="${1}"
shift

zdebug "Calling ${func} with $*"

$func "$@"
