#!/bin/bash

## This early-setup hook forces the dracut console initialization hook to run.
##
## ZFSBootMenu release builds embed rd.hostonly=0 in the kernel command line,
## which causes the normal dracut initqueue to be thrown out; the ZFSBootMenu
## initqueue hooks that force the dracut event loop to run at least once are
## purged, so dracut terminates the event loop before console initialization.
##

# There is nothing to do if we're not in dracut
[ "${ZBM_BUILDSTYLE,,}" = "dracut" ] || exit 0

# There is nothing to do if the console initializer is not executable
[ -x /lib/udev/console_init ] || exit 0

if [ -z "${control_term}" ] && [ -f /etc/zfsbootmenu.conf ]; then
  # If control_term isn't defined, check the runtime config for it
  # shellcheck disable=SC1091
  source /etc/zfsbootmenu.conf
fi

# There is nothing to do without a valid control_term device
[ -c "${control_term}" ] || exit 0

# print an "empty" string to the screen to force it to recalculate
# with out this, EFI frame buffers will possibly have the wrong size
echo -e "\033[0;30m ... \033[0m"

# Try to initialize the console
/lib/udev/console_init "${control_term##*/}" >/dev/null 2>&1
