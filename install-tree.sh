#!/bin/sh
# vim: softtabstop=2 shiftwidth=2 expandtab

set -e

src="${1?must specify a source directory}"
dst="${2?must specify a target directory}"

if ! [ -d "${src}" ]; then
  echo "ERROR: source directory ${src} does not exist"
  exit 1
fi

if ! dst="$(realpath -m "${dst}")"; then
  echo "ERROR: failed to canonicalize ${2}"
  exit 1
fi

cd "${src}"

find . -type f -perm /111 -exec install -Dm 0755 "{}" "${dst}/{}" \;
find . -type f -not -perm /111 -exec install -Dm 0644 "{}" "${dst}/{}" \;
