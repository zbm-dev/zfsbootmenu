#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# shellcheck disable=SC1091
[ -r /lib/zfsbootmenu-lib.sh ] && source /lib/zfsbootmenu-lib.sh

ENV="${1}"
BOOTFS="${2}"

# shellcheck disable=SC2034
IFS=' ' read -r _fs selected_kernel _initramfs <<<"$( select_kernel "${ENV}")"
selected_kernel="${selected_kernel##*/}"

pool="${ENV%%/*}"
if is_writable "${pool}" ; then
  _readonly="r/w"
  _COLOR="red"
else
  _readonly="r/o"
  _COLOR="green"
fi

if [ "${BOOTFS}" = "${ENV}" ]; then
  _DEFAULT="default, "
else
  _DEFAULT=""
fi

selected_arguments="$( load_be_cmdline "${ENV}" )"
selected_arguments="$( center_string "$( load_be_cmdline "${ENV}" )" )"

selected_env_str="$( center_string "${ENV} (${_DEFAULT}${_readonly}) - ${selected_kernel}" )"

# colorize doesn't automatically add a newline
if [ -f "${BASE}/have_errors" ]; then
  selected_env_str="${selected_env_str:3}"
  colorize "red" "[!]"
fi

colorize "${_COLOR}" "${selected_env_str}\n"
echo "${selected_arguments}"
