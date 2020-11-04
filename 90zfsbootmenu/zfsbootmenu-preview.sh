#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

BASE="${1}"
ENV="${2}"
BOOTFS="${3}"

# shellcheck disable=SC2034
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# shellcheck disable=SC1091
test -f /lib/zfsbootmenu-lib.sh && source /lib/zfsbootmenu-lib.sh

while IFS= read -r line
do
  selected_kernel="${line}"
done < "${BASE}/${ENV}/default_kernel"

BE_ARGS="$( load_be_cmdline "${ENV}" )"

while IFS= read -r line
do
  selected_arguments="${line}"
done <<< "${BE_ARGS}"

pool="${ENV%%/*}"
readonly_prop="$( zpool get -H -o value readonly "${pool}" )"
[[ ${readonly_prop} = "on" ]] && _readonly="r/o" || _readonly="r/w"

if [ "${BOOTFS}" = "${ENV}" ]; then
  selected_env_str="${ENV} (default, ${_readonly}) - ${selected_kernel}"
else
  selected_env_str="${ENV} (${_readonly}) - ${selected_kernel}"
fi

if [ -z "${FZF_PREVIEW_COLUMNS}" ]
then
  WIDTH="$( tput cols )"
else
  WIDTH="${FZF_PREVIEW_COLUMNS}"
fi

# Left pad the strings to center them based on the preview width
selected_env_str="$( printf "%*s\n" $(( (${#selected_env_str} + WIDTH ) / 2)) "${selected_env_str}" )"
selected_arguments="$( printf "%*s\n" $(( (${#selected_arguments} + WIDTH ) / 2)) "${selected_arguments}" )"

if [ "${_readonly}" = "r/o" ]; then
  echo -e "${GREEN}${selected_env_str}${NC}"
else
  echo -e "${RED}${selected_env_str}${NC}"
fi

echo "${selected_arguments}"
