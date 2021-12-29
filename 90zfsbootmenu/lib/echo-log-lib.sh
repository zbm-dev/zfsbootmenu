#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

: "${loglevel:=3}"

# arg1: log line
# prints: log line 
# returns: 1 if loglevel isn't high enough

zdebug() {
  [ "${loglevel:-4}" -ge 7 ] || return 1
  echo "DEBUG: $*" 
}

zinfo() {
  [ "${loglevel:-4}" -ge 6 ] || return 1
  echo "INFO: $*"
}

znotice() {
  [ "${loglevel:-4}" -ge 5 ] || return 1
  echo "NOTICE: $*"
}

zwarn() {
  [ "${loglevel:-4}" -ge 4 ] || return 1
  echo "WARN: $*"
}

zerror() {
  [ "${loglevel:-4}" -ge 3 ] || return 1
  echo "ERROR: $*"
}
