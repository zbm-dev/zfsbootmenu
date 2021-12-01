#!/bin/bash

[ -f "${BASE}/have_errors" ] && rm "${BASE}/have_errors"
[ -f "${BASE}/have_warnings" ] && rm "${BASE}/have_warnings"

fuzzy_default_options+=(
 "--no-sort" "--ansi" "--tac" "--no-mouse"
 "--bind" '"ctrl-q:ignore,ctrl-c:ignore,ctrl-g:ignore,enter:ignore"'
)

export FZF_DEFAULT_OPTS="${fuzzy_default_options[*]}"

# shellcheck disable=SC2086
dmesg -T --time-format reltime -f user,daemon -l err,warn | ${FUZZYSEL}
