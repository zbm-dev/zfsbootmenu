#!/bin/bash

BASE="${1}"
ENV="${2}"
BOOTFS="${3}"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

while IFS= read -r line
do
  selected_kernel="${line}"
done < "${BASE}/${ENV}/default_kernel"

while IFS= read -r line
do
  selected_arguments="${line}"
done < "${BASE}/${ENV}/default_args"

if [[ "${BOOTFS}" =~ "${ENV}" ]]; then
  selected_env_str="${ENV} (default) - ${selected_kernel}"
else
  selected_env_str="${ENV} - ${selected_kernel}"
fi

# Left pad the strings to center them based on the preview width
selected_env_str="$( printf "%*s\n" $(( (${#selected_env_str} + FZF_PREVIEW_COLUMNS) / 2)) "${selected_env_str}" )"
selected_arguments="$( printf "%*s\n" $(( (${#selected_arguments} + FZF_PREVIEW_COLUMNS) / 2)) "${selected_arguments}" )"

echo -e "${GREEN}${selected_env_str}${NC}"
echo "${selected_arguments}"
