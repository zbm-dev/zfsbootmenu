#!/bin/bash

dmesg -T --time-format reltime --noescape -w | fzf --no-sort --ansi --tac --no-info
