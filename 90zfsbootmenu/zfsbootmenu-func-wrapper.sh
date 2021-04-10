#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# shellcheck disable=SC1091
[ -r /lib/zfsbootmenu-lib.sh ] && source /lib/zfsbootmenu-lib.sh

# First argument is the function name
# the rest are positional params
func="${1}"
shift

zdebug "Calling ${func} with $*"

$func "$@"
