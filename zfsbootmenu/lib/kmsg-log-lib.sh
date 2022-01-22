#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

if [ -n "${_ZFSBOOTMENU_KMSG_LOG_LIB}" ]; then
  [ -z "${FORCE_RELOAD}" ] && return
else
  readonly _ZFSBOOTMENU_KMSG_LOG_LIB=1
fi

: "${loglevel:=4}"

# arg1..argN: log line
# prints: nothing
# returns: 1 if loglevel isn't high enough

zdebug() {
  [ ${loglevel:-4} -ge 7 ] || return 1
  local prefix trace last lines line lc i

  # Remove everything but new lines from the string, count the length
  lines="${1//[!$'\n']/}"
  lines="${#lines}"

  while IFS=$'\n' read -r line ; do
    if [ "${lc:=0}" -eq "${lines}" ] ; then
      trace=
      last=${#BASH_SOURCE[@]}
      for (( i=1 ; i<last ; i++ )) ; do
        trace="${FUNCNAME[$i]},${BASH_SOURCE[$i]},${BASH_LINENO[$i-1]}${trace:+;}${trace}"
      done
      prefix="<7>ZBM:[$$]|${trace}|"
    else
      prefix="<7>ZBM:[$$]||"
    fi
    lc=$(( lc + 1 ))
    echo "${prefix}${line}" > /dev/kmsg
  done <<<"${1}"
}

if [ ${loglevel:-4} -ge 7 ] ; then
  # Trap errors and send them to the debug handler
  traperror() {
    zdebug "trapped error from: '${BASH_COMMAND}'"
  }

  trap traperror ERR
  set -o errtrace
fi

# arg1: log line
# prints: nothing
# returns: 1 if loglevel isn't high enough

zinfo() {
  [ "${loglevel:-4}" -ge 6 ] || return 1
  echo "<6>ZFSBootMenu: $1" > /dev/kmsg
}

# arg1: log line
# prints: nothing
# returns: 1 if loglevel isn't high enough

znotice() {
  [ "${loglevel:-4}" -ge 5 ] || return 1
  echo "<5>ZFSBootMenu: $1" > /dev/kmsg
}

# arg1: log line
# prints: nothing
# returns: 1 if loglevel isn't high enough

zwarn() {
  [ "${loglevel:-4}" -ge 4 ] || return 1
  : > "${BASE}/have_warnings"
  echo "<4>ZFSBootMenu: $1" > /dev/kmsg
}

# arg1: log line
# prints: nothing
# returns: 1 if loglevel isn't high enough

zerror() {
  [ "${loglevel:-4}" -ge 3 ] || return 1
  : > "${BASE}/have_errors"
  echo "<3>ZFSBootMenu: $1" > /dev/kmsg
}
