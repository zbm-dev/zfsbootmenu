#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

: "${loglevel:=4}"

# arg1: log level
# arg2: log line
# prints: nothing
# returns: nothing

zlog() {
  local prefix trace last lines line lc i
  [ -z "${1}" ] && return
  [ -z "${2}" ] && return

  # Remove everything but new lines from the string, count the length
  lines="${2//[!$'\n']/}"
  lines="${#lines}"
  lc=0

  while IFS=$'\n' read -r line ; do
    # Only add script/function tracing to debug messages
    if [ "${1}" -eq 7 ] && [ "${lc}" -eq "${lines}" ] ; then
      trace=
      last=${#BASH_SOURCE[@]}
      for (( i=2 ; i<last ; i++ )) ; do
        trace="${FUNCNAME[$i]},${BASH_SOURCE[$i]},${BASH_LINENO[$i-1]}${trace:+;}${trace}"
      done
      prefix="<${1}>ZBM:[$$]|${trace}|"
    elif [ "${1}" -eq 7 ] ; then
      prefix="<${1}>ZBM:[$$]||"
    else
      prefix="<${1}>ZFSBootMenu: "
    fi
    lc=$(( lc + 1 ))
    echo -e "${prefix}${line}" > /dev/kmsg
  done <<<"${2}"
}

# arg1: log line
# prints: nothing
# returns: 1 if loglevel isn't high enough

zdebug() {
  [ "${loglevel:-4}" -ge 7 ] || return 1
  zlog 7 "$@"
}

zinfo() {
  [ "${loglevel:-4}" -ge 6 ] || return 1
  zlog 6 "$@"
}

znotice() {
  [ "${loglevel:-4}" -ge 5 ] || return 1
  zlog 5 "$@"
}

zwarn() {
  [ "${loglevel:-4}" -ge 4 ] || return 1
  : > "${BASE}/have_warnings"
  zlog 4 "$@"
}

zerror() {
  [ "${loglevel:-4}" -ge 3 ] || return 1
  : > "${BASE}/have_errors"
  zlog 3 "$@"
}

traperror() {
  zdebug "trapped error from: '${BASH_COMMAND}'"
}

if [ "${loglevel:-4}" -eq 7 ] ; then
  set -o errtrace
  set -o functrace
  trap traperror ERR
fi
