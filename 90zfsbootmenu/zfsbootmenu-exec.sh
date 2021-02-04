#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

export spl_hostid
export force_import
export menu_timeout
export loglevel
export root
export zbm_sort

# store current kernel log level
read -r PRINTK < /proc/sys/kernel/printk
PRINTK=${PRINTK:0:1}
export PRINTK

# Set it to 0
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

modprobe zfs 2>/dev/null
udevadm settle

# try to set console options for display and interaction
# this is sometimes run as an initqueue hook, but cannot be guaranteed
#shellcheck disable=SC2154
[ -x /lib/udev/console_init ] && [ -c "${control_term}" ] \
  && /lib/udev/console_init "${control_term##*/}" >/dev/null 2>&1

#shellcheck disable=SC2154
if [ -n "${zbm_tmux}" ] && [ -x /bin/tmux ]; then
  tmux new-session -n ZFSBootMenu -d /libexec/zfsbootmenu-countdown
  tmux new-window -n logs /bin/zlogtail
  tmux new-window -n shell /bin/bash
  exec tmux attach-session \; select-window -t ZFSBootMenu
else
  # https://busybox.net/FAQ.html#job_control
  exec setsid bash -c "exec /libexec/zfsbootmenu-countdown <${control_term} >${control_term} 2>&1"
fi
