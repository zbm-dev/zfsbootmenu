#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

for style in release recovery; do
  (
    for include in "etc/zfsbootmenu/${style}.conf.d"/*; do
      # shellcheck disable=SC1090
      source "${include}"
    done

    # shellcheck disable=SC2154
    read -ra installs <<< "${install_optional_items}"
    for item in "${installs[@]}"; do
      echo "* ``$item``"
    done
  ) > docs/guides/_include/${style}.rst
done
