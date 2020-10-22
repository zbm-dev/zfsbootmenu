#!/bin/bash

export spl_hostid
export force_import
export menu_timeout
export root

# https://busybox.net/FAQ.html#job_control
exec setsid bash -c 'exec /bin/zfsbootmenu </dev/tty1 >/dev/tty1 2>&1'
