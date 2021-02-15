#!/bin/bash

PID_FILE="$( mktemp --tmpdir="${BASE}" )"
export PID_FILE
trap 'rm -f ${PID_FILE}' EXIT

#shellcheck disable=SC2154
LOG_LEVEL="${loglevel:-err}"
FOLLOW=""
ALLOW_EXIT=1
while getopts "fnl:" opt; do
  case "${opt}" in
    l)
      LOG_LEVEL="${OPTARG}"
      ;;
    n)
      ALLOW_EXIT=0
      ;;
    f)
      FOLLOW="-w"
      ;;
    *)
      ;;
  esac
done

fuzzy_default_options+=("--bind")
fuzzy_default_options+=('"ctrl-q:ignore,ctrl-c:ignore,ctrl-g:ignore,enter:ignore"')

if ((ALLOW_EXIT)) ; then
  fuzzy_default_options+=("--bind")
  # shellcheck disable=SC2016
  fuzzy_default_options+=('"esc:execute-silent[ kill $( cat ${PID_FILE} ) ]+abort"')
else
  fuzzy_default_options+=("--bind")
  fuzzy_default_options+=('"esc:ignore"')
fi

if command -v fzf >/dev/null 2>&1; then
  FUZZYSEL=fzf
  export FZF_DEFAULT_OPTS="--no-mouse --no-sort --ansi --tac --no-info ${fuzzy_default_options[*]}"
elif command -v sk >/dev/null 2>&1; then
  FUZZYSEL=sk
  export SKIM_DEFAULT_OPTIONS="--no-sort --ansi --tac ${fuzzy_default_options[*]}"
fi

 # shellcheck disable=SC2086
( dmesg -T --time-format reltime --noescape -l ${LOG_LEVEL} ${FOLLOW} & echo $! >&3 ) \
  3>"${PID_FILE}" \
  | ${FUZZYSEL}
