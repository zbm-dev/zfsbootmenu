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
  [ "${loglevel:-4}" -ge 7 ] || return 1
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

if [ "${loglevel:-4}" -ge 7 ] ; then
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

# arg1: comma-separated log levels to print
# arg2: optional date that messages must be timestamped after
# prints: all logs at that level
# returns: nothing

print_kmsg_logs() {
  local levels levels_array grep_args

  levels="${1}"
  if [ -z "${levels}" ]; then
    zerror "levels is undefined"
    return
  fi

  since="${2}"

  # dmesg from dmesg-util can helpfully do --since, but only if it's also allowed to print the time out
  # so always print the time, optionally set --since, and filter the timestamp after
  if output="$( dmesg -f user --color=never -l "${levels}" ${since:+--since ${since}} 2>/dev/null )" ; then
    # shellcheck disable=SC2001
    echo "${output}" | sed 's/^\[.*\]\ //'
  else
    # Both util-linux and Busybox dmesg support the -r flag. However, the log level that is
    # reported by Busybox dmesg is larger than that reported by util-linux dmesg. Busybox dmesg
    # is too bare-bones to do much of anything, so we just need to grep for both integers at 
    # a given log level, then rely on matching ZFSBootMenu for info and lower, and ZBM for debug.

    IFS=',' read -r -a levels_array <<<"${levels}"
    for level in "${levels_array[@]}"; do
      case "${level}" in
        err)
          grep_args+=( "-e" "^<11>" "-e" "^<3>" )
          ;;
        warn)
          grep_args+=( "-e" "^<12>" "-e" "^<4>" )
          ;;
        notice)
          grep_args+=( "-e" "^<13>" "-e" "^<5>" )
          ;;
        info)
          grep_args+=( "-e" "^<14>" "-e" "^<6>" )
          ;;
        debug)
          grep_args+=( "-e" "^<15>" "-e" "^<7>" )
          ;;
        *)
          grep_args+=( "-e" "." )
          ;;
      esac
    done

    dmesg -r | grep "${grep_args[@]}" \
      | awk '
          /ZFSBootMenu:/{ for (i=3; i<=NF; i++){ printf("%s ", $i)}; printf "\n" }
          /ZBM:/{ for (i=3; i<=NF; i++){ printf("%s ", $i)}; printf "\n" }
        '
  fi
}

