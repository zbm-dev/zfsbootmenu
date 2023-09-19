#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# shellcheck disable=1091
source /etc/profiling.conf >/dev/null 2>&1 || exit 0

trapdebug() {
  #shellcheck disable=SC2154
  echo "${FUNCNAME[*]};${BASH_SOURCE[*]};${BASH_LINENO[*]};${EPOCHREALTIME}" > "${zfsbootmenu_trace_term}" 2>/dev/null || true
}

#shellcheck disable=SC2154
stty -F "${zfsbootmenu_trace_term}" "${zfsbootmenu_trace_baud}"
trap trapdebug DEBUG
set -o functrace
