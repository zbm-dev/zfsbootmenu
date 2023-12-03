#!/bin/bash

cleanup() {
  [ -f "${MASTER_COMMITS}" ] && rm "${MASTER_COMMITS}"
  [ -f "${RELEASE_COMMITS}" ] && rm "${RELEASE_COMMITS}"
  [ -n  "${CUR_BRANCH}" ] && git checkout "${CUR_BRANCH}"
}

usage() {
  cat <<-EOF

Usage: $0 [OPTIONS]

OPTIONS
  -m  <master branch>
      Set the master branch, otherwise default to 'master'

  -r  <release branch>
      Set the release tracking branch

  -t  <common tag>
      Set the tag where commits diverged

  -h  Show this message and exit
EOF
exit
}

MASTER="master"
RELEASE=
TAG=

while getopts "m:r:t:h" opt; do
  case "${opt}" in
    m)
      MASTER="${OPTARG}"
      ;;
    r)
      RELEASE="${OPTARG}"
      ;;
    t)
      TAG="${OPTARG}"
      ;;
    h|*)
      usage
      ;;
  esac
done

[ -z "${RELEASE}" ] && usage
[ -z "${TAG}" ] && usage

CUR_BRANCH="$( git rev-parse --abbrev-ref HEAD )"

trap cleanup EXIT INT TERM

MASTER_COMMITS="$( mktemp )"
RELEASE_COMMITS="$( mktemp )"

(
  git checkout "${MASTER}" && git log --format="%h;%s (%an)" "${TAG}..HEAD" > "${MASTER_COMMITS}"
  git checkout "${RELEASE}" && git log --format="%h;%s (%an)" "${TAG}..HEAD" > "${RELEASE_COMMITS}"
  git checkout "${CUR_BRANCH}"
) >/dev/null 2>&1 

while IFS=';' read -r sha message; do
  if grep -q "${message}" "${RELEASE_COMMITS}" ; then
    continue
  else
    echo "* ${sha} ${message}"
  fi
done < "${MASTER_COMMITS}"
