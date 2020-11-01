#!/bin/bash

export spl_hostid
export force_import
export menu_timeout
export root
export control_term
export zbm_lines
export zbm_columns

# https://busybox.net/FAQ.html#job_control
exec setsid bash -c "exec /bin/zfsbootmenu <${control_term} >${control_term} 2>&1"
