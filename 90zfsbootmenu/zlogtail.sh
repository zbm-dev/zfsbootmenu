#!/bin/bash

# Ignore keys in a future release
# --bind "ctrl-c:ignore,ctrl-g:ignore,esc:ignore,enter:ignore"

if command -v fzf >/dev/null 2>&1; then
  FUZZYSEL=fzf
  export FZF_DEFAULT_OPTS='--no-mouse --no-sort --ansi --tac --no-info'
elif command -v sk >/dev/null 2>&1; then
  FUZZYSEL=sk
  export SKIM_DEFAULT_OPTIONS='--no-sort --ansi --tac'
fi

dmesg -T --time-format reltime --noescape -w | ${FUZZYSEL}
