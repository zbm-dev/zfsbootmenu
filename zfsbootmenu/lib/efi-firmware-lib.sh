#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

source /lib/kmsg-log-lib.sh >/dev/null 2>&1 || exit 1
source /lib/zfsbootmenu-core.sh >/dev/null 2>&1 || exit 1

check_fw_setup() {
  local osind_path="/sys/firmware/efi/efivars/OsIndications-8be4df61-93ca-11d2-aa0d-00e098032b8c"
  local osind_supp_path="/sys/firmware/efi/efivars/OsIndicationsSupported-8be4df61-93ca-11d2-aa0d-00e098032b8c"
  if ! is_efi_system; then
    zdebug "efivarfs unsupported"
    return 1
  elif [ ! -r "${osind_supp_path}" ]; then
    zdebug "OsIndicationsSupported unsupported"
    return 1
  elif [ ! -r "${osind_path}" ]; then
    zdebug "OsIndications unsupported"
    return 1
  fi

  # Check if the EFI_OS_INDICATIONS_BOOT_TO_FW_UI = 0x01 bit is set
  if ! (( $(od -An -t u1 -j4 -N1 "${osind_supp_path}" | tr -dc '0-9') & 1 )); then
    zdebug "EFI reboot to firmware setup unsupported"
    return 1
  fi
}

set_fw_setup() {
  local bytes osind_path="/sys/firmware/efi/efivars/OsIndications-8be4df61-93ca-11d2-aa0d-00e098032b8c"
  local -a osindications

  mount_efivarfs rw
  if [ ! -w "${osind_path}" ]; then
    zdebug "OsIndications not writable"
    return 1
  fi

  mapfile -t osindications < <(od -An -t x1 -v -w1 "${osind_path}" | tr -dc '[:alnum:]\n')

  # Set the EFI_OS_INDICATIONS_BOOT_TO_FW_UI = 0x01 bit if not already set
  if ! (( "${osindications[4]}" & 0x01 )); then
    printf -v osindications[4] '%02x' $(( 0x"${osindications[4]}" | 0x01 ))

    printf -v bytes '\\x%02x' "${osindications[@]}"
    printf '%b' "$bytes" > "${osind_path}"
  fi
}
