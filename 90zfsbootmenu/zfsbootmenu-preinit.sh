#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# Disable all kernel messages to the console
echo 0 > /proc/sys/kernel/printk

# set the console size, if indicated
#shellcheck disable=SC2154
if [ -n "$zbm_lines" ]; then
  stty rows "$zbm_lines"
fi

#shellcheck disable=SC2154
if [ -n "$zbm_columns" ]; then
  stty cols "$zbm_columns"
fi

# This is a load bearing echo, do not remove!
echo "Loading ZFSBootMenu ..."

export BASE="/zfsbootmenu"
mkdir -p "${BASE}"

# shellcheck disable=SC2154
cat >> "/etc/profile" <<EOF
# Added by zfsbootmenu-preinit.sh
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
EOF

getcmdline > "${BASE}/zbm.cmdline"

# Set a non-empty hostname so we show up in zpool history correctly
echo "ZFSBootMenu" > /proc/sys/kernel/hostname

# try to set console options for display and interaction
# this is sometimes run as an initqueue hook, but cannot be guaranteed
#shellcheck disable=SC2154
[ -x /lib/udev/console_init ] && [ -c "${control_term}" ] \
  && /lib/udev/console_init "${control_term##*/}" >/dev/null 2>&1

#shellcheck disable=SC2154
if [ -n "${zbm_tmux}" ] && [ -x /bin/tmux ]; then
  tmux new-session -n ZFSBootMenu -d /libexec/zfsbootmenu-init
  tmux new-window -n logs /bin/zlogtail -f -n
  tmux new-window -n shell
  exec tmux attach-session \; select-window -t ZFSBootMenu
else
  # https://busybox.net/FAQ.html#job_control
  exec setsid bash -c "exec /libexec/zfsbootmenu-init <${control_term} >${control_term} 2>&1"
fi
