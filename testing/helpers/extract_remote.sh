#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

#shellcheck disable=2317
cleanup() {
  if [ -d "${FETCH_DIR}" ]; then
    rm -rf "${FETCH_DIR}"
    unset FETCH_DIR
  fi
  exit
}

untar() {
  local fname="${1?a file name is required}"
  shift

  case "${fname}" in
    *.zstd|*.zst)
      zstdcat "${fname}" | tar -x -f - "$@"
      ;;
    *)
      tar -x -f "${fname}" "$@"
      ;;
  esac
}

REMOTE_URL="${1?A remote URL is required}"
TARGET_DIR="${2?A target directory is required}"

REMOTE_PATTERN="$3"

if [ ! -d "${TARGET_DIR}" ]; then
  echo "ERROR: target directory ${TARGET_DIR} does not exist"
  exit 1
fi

FILENAME=""
if [ -n "${REMOTE_PATTERN}" ]; then
  # Scrape file name from index page
  FILENAME="$( curl -s -L "${REMOTE_URL}" | \
    grep -o "${REMOTE_PATTERN}" | sort -Vr | head -n1 | tr -d '\n' )"
  # Append file name to URL for fetch
  REMOTE_URL="${REMOTE_URL}/${FILENAME}"
else
  # Strip scheme from URL
  _remote_path="${REMOTE_URL#*://}"
  # Strip trailing slash, if one exists
  _remote_path="${_remote_path%/}"
  # Extract file name; if there is no slash there is no file name
  FILENAME="${_remote_path##*/}"
  if [ "${FILENAME}" = "${_remote_path}" ]; then
    FILENAME=""
  fi
fi

if [ -z "${FILENAME}" ]; then
  echo "ERROR: unable to determine file name from URL '${REMOTE_URL}'"
  exit 1
fi

: "${CACHEDIR:=./cache}"

if [ -d "${CACHEDIR}" ]; then
  # Make sure a fetch cache directory exists
  mkdir -p "${CACHEDIR}/fetch"


  # If the file is already cached, just extract it if possible
  if [ -r "${CACHEDIR}/fetch/${FILENAME}" ]; then
    if ! untar "${CACHEDIR}/fetch/${FILENAME}" -C "${TARGET_DIR}"; then
      echo "ERROR: extraction of cached file '${CACHEDIR}/fetch/${FILENAME}' failed"
    else
      exit 0
    fi
  fi
fi

trap cleanup EXIT INT TERM

if ! FETCH_DIR="$( mktemp -d )"; then
  echo "ERROR: cannot create temporary fetch directory"
  exit 1
fi

export FETCH_DIR

if ! curl -L -s -o "${FETCH_DIR}/${FILENAME}" "${REMOTE_URL}"; then
  echo "ERROR: failed to fetch image file ${REMOTE_URL}'"
  exit 1
fi

if ! untar "${FETCH_DIR}/${FILENAME}" -C "${TARGET_DIR}"; then
  echo "ERROR: extraction of fetched file '${REMOTE_URL}' failed"
  exit 1
fi

if [ -d "${CACHEDIR}/fetch" ]; then
  cp "${FETCH_DIR}/${FILENAME}" "${CACHEDIR}/fetch/${FILENAME}"
fi

exit 0
