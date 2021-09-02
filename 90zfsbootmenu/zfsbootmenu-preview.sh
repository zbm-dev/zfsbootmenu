#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# shellcheck disable=SC1091
[ -r /lib/zfsbootmenu-lib.sh ] && source /lib/zfsbootmenu-lib.sh

ENV="${1}"
BOOTFS="${2}"

# shellcheck disable=SC2034
IFS=' ' read -r _fs selected_kernel _initramfs <<<"$( select_kernel "${ENV}")"
selected_kernel="${selected_kernel##*/}"

if [ "${BOOTFS}" = "${ENV}" ]; then
  _EXTRAS+=( "default," )
fi

if be_has_encroot "${ENV}" >/dev/null; then
  _EXTRAS+=( "encrypted," )
fi

pool="${ENV%%/*}"
if is_writable "${pool}" ; then
  _EXTRAS+=( "r/w" )
  _COLOR="red"
else
  _EXTRAS+=( "r/o" )
  _COLOR="green"
fi

selected_arguments="$( center_string "$( load_be_cmdline "${ENV}" )" )"

selected_env_str="$( center_string "${ENV} (${_EXTRAS[*]}) - ${selected_kernel}" )"

# colorize doesn't automatically add a newline
if [ -f "${BASE}/have_errors" ]; then
  selected_env_str="${selected_env_str:3}"
  colorize "red" "[!]"
elif [ -f "${BASE}/have_warnings" ]; then
  selected_env_str="${selected_env_str:3}"
  colorize "yellow" "[!]"
fi

colorize "${_COLOR}" "${selected_env_str}\n"
echo "${selected_arguments}"

if [ -n "${3}" ]; then
  context="$( center_string "${3}" )"
  colorize "orange" "${context}"
fi
