#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

release="${1?ERROR: no release version specified}"
assets="$( realpath -e releng )/assets/${release}"

if [ ! -d "${assets}" ]; then
  echo "ERROR: ${assets} directory does not exist"
  exit 1
fi

if ! ( cd "${assets}" && rm -f sha256.txt && sha256sum --tag -- * > sha256.txt ); then
  echo "ERROR: unable to compute asset checksums"
  exit 1
fi

# Sign if key is present
signkey="$( realpath -e releng )/keys/zfsbootmenu.sec"
if [ ! -r "${signkey}" ]; then
  echo "ERROR: ${signkey} file is not readable"
  exit 1
fi

if ! command -v signify >/dev/null 2>&1; then
  echo "ERROR: signify is missing"
  exit 1
fi

if ! pass show zfsbootmenu/signpass >/dev/null 2>&1; then
  echo "ERROR: pass command does not provide passphrase for signify key"
  exit 1
fi

if ! pass show zfsbootmenu/signpass | \
      signify -S -s "${signkey}" -x "${assets}/sha256.sig" \
        -e -s "${signkey}" -m "${assets}/sha256.txt"; then
  echo "ERROR: failed to sign checksum file"
  exit 1
fi

pubkey="${signkey%.sec}.pub"
if [ -r "${pubkey}" ]; then
  if ! ( cd "${assets}" && signify -C -p "${pubkey}" -x sha256.sig ); then
    echo "ERROR: unable to verify asset signature"
    exit 1
  fi
fi

exit 0
