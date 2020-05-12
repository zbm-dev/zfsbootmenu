#!/bin/bash

BASE="${1}"
ENV="${2}"
BOOTFS="${3}"

# shellcheck disable=SC2034
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

while IFS= read -r line
do
  selected_kernel="${line}"
done < "${BASE}/${ENV}/default_kernel"

if [ -f "${BASE}/default_args" ]
then
  ARGS="${BASE}/default_args"
else
  ARGS="${BASE}/${ENV}/default_args"
fi

while IFS= read -r line
do
  selected_arguments="${line}"
done < "${ARGS}"

if [[ "${BOOTFS}" =~ ${ENV} ]]; then
  selected_env_str="${ENV} (default) - ${selected_kernel}"
else
  selected_env_str="${ENV} - ${selected_kernel}"
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

echo -e "${GREEN}${selected_env_str}${NC}"
echo "${selected_arguments}"
