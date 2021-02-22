#!/bin/bash

PID_FILE="$( mktemp --tmpdir="${BASE}" )"
export PID_FILE
trap 'rm -f ${PID_FILE}' EXIT

#shellcheck disable=SC2154
LOG_LEVEL="0,1,2,3,4,5,6,7"
FACILITY="kern,user,daemon"
FOLLOW=""
ALLOW_EXIT=1
while getopts "cfnl:F:" opt; do
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
    c)
      [ -f "${BASE}/have_errors" ] && rm "${BASE}/have_errors"
      ;;
    F)
      FACILITY="${OPTARG}"
      ;;
    *)
      ;;
  esac
done

fuzzy_default_options+=("--no-sort")
fuzzy_default_options+=("--ansi")
fuzzy_default_options+=("--tac")

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
  export FZF_DEFAULT_OPTS="--no-mouse --no-info ${fuzzy_default_options[*]}"
elif command -v sk >/dev/null 2>&1; then
  FUZZYSEL=sk
  export SKIM_DEFAULT_OPTIONS="${fuzzy_default_options[*]}"
fi

 # shellcheck disable=SC2086
( dmesg -T --time-format reltime --noescape -f ${FACILITY} -l ${LOG_LEVEL} ${FOLLOW} & echo $! >&3 ) \
  3>"${PID_FILE}" \
  | ${FUZZYSEL}
