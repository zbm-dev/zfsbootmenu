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
mkdir -p "${BASE}"

# shellcheck disable=SC2154
cat >> "/etc/zfsbootmenu.conf" <<EOF
# BEGIN additions by zfsbootmenu-preinit.sh
export BASE="/zfsbootmenu"
export endian="${endian}"
export spl_hostid="${spl_hostid}"
export import_policy="${import_policy}"
export menu_timeout="${menu_timeout}"
export loglevel="${loglevel}"
export root="${root}"
export zbm_require_bpool="${zbm_require_bpool}"
export default_hostid=00bab10c
export zbm_sort="${zbm_sort}"
export zbm_set_hostid="${zbm_set_hostid}"
export zbm_import_delay="${zbm_import_delay}"
export control_term="${control_term}"
# END additions by zfsbootmenu-preinit.sh
EOF

getcmdline | sed -e 's/^[ \t]*//' > "${BASE}/zbm.cmdline"

# Set a non-empty hostname so we show up in zpool history correctly
echo "ZFSBootMenu" > /proc/sys/kernel/hostname

# https://busybox.net/FAQ.html#job_control
exec setsid bash -c "exec /libexec/zfsbootmenu-init <${control_term} >${control_term} 2>&1"
