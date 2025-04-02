#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# Disable all kernel messages to the console
echo 0 > /proc/sys/kernel/printk

# fzf needs stty cols/rows explicitly set, otherwise it can't
# determine the serial terminal size. Defaults should only be
# called when the controlling terminal is NOT /dev/tty[0-9]

tty_re='/dev/tty[0-9]'

#shellcheck disable=SC2154
if ! [[ ${control_term} =~ ${tty_re} ]]; then
  stty rows "${zbm_lines:-25}"
  stty cols "${zbm_columns:-80}"
fi

export BASE="/zfsbootmenu"

# shellcheck disable=SC2154
cat >> "/etc/zfsbootmenu.conf" <<EOF
# BEGIN additions by zfsbootmenu-preinit.sh
export BASE='${BASE}'
export spl_hostid='${spl_hostid}'
export import_policy='${import_policy}'
export menu_timeout='${menu_timeout}'
export loglevel='${loglevel}'
export zbm_prefer_pool='${zbm_prefer_pool}'
export zbm_require_pool='${zbm_require_pool}'
export zbm_prefer_bootfs='${zbm_prefer_bootfs}'
export default_hostid=00bab10c
export zbm_sort='${zbm_sort}'
export zbm_set_hostid='${zbm_set_hostid}'
export zbm_retry_delay='${zbm_retry_delay}'
export zbm_hook_root='${zbm_hook_root}'
export zbm_wait_for_devices='${zbm_wait_for_devices}'
export control_term='${control_term}'
# END additions by zfsbootmenu-preinit.sh
EOF

# Set a non-empty hostname so we show up in zpool history correctly
echo "ZFSBootMenu" > /proc/sys/kernel/hostname

# https://busybox.net/FAQ.html#job_control
ZFSBOOTMENU_CONSOLE=yes exec setsid \
    bash -c "exec /libexec/zfsbootmenu-init <${control_term} >${control_term} 2>&1"
