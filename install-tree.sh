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

mkdir -p "${dst}"
( cd "${src}" && tar -cf - . ) | tar -xvf - -C "${dst}" --no-same-owner
