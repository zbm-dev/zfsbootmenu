#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# shellcheck disable=SC1091
[ -r /lib/zfsbootmenu-lib.sh ] && source /lib/zfsbootmenu-lib.sh

ENV="${1}"
BOOTFS="${2}"

# Skim doesn't set the environment
if [ -z "${FZF_PREVIEW_COLUMNS}" ]; then
  WIDTH="$( tput cols )"
else
  WIDTH="${FZF_PREVIEW_COLUMNS}"
fi

# shellcheck disable=SC2034
IFS=' ' read -r _fs selected_kernel _initramfs <<<"$( select_kernel "${ENV}")"
selected_kernel="${selected_kernel%/*}"
selected_arguments="$( load_be_cmdline "${ENV}" )"

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

selected_env_str="${ENV} (${_DEFAULT}${_readonly}) - ${selected_kernel}"

# Left pad the strings to center them based on the preview width
selected_env_str="$( printf "%*s\n" $(( (${#selected_env_str} + WIDTH ) / 2)) "${selected_env_str}" )"
selected_arguments="$( printf "%*s\n" $(( (${#selected_arguments} + WIDTH ) / 2)) "${selected_arguments}" )"

# colorize doesn't automatically add a newline
colorize "${_COLOR}" "${selected_env_str}\n"
echo "${selected_arguments}"
