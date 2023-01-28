#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

## This early-setup hook attempts to get a physical (non-serial) console
## to at least 100 columns. The Dracut module 'i18n' is required to populate
## /usr/share/consolefonts and to add the 'setfont' binary.
##
## This hook is enabled by default in Release and Recovery builds. To disable,
## add `zbm.autosize=off` to the ZFSBootMenu kernel commandline.
## If rd.vconsole.font is defined, autosizing is skipped to not override
## this font preference.


#shellcheck disable=SC1091
source /lib/zfsbootmenu-kcl.sh || exit 1
source /lib/kmsg-log-lib.sh || exit 1

if [ -z "${control_term}" ] && [ -f /etc/zfsbootmenu.conf ]; then
  #shellcheck disable=SC1091
  source /etc/zfsbootmenu.conf
fi

[ -c "${control_term}" ] || exit 1

# Ensure that control_term is not a serial console
tty_re='/dev/tty[0-9]'
[[ ${control_term} =~ ${tty_re} ]] || exit 1

if get_zbm_bool 1 zbm.autosize && ! font=$( get_zbm_arg rd.vconsole.font ) ; then
  for font in ter-v32b ter-v28b ter-v24b ter-v20b ter-v14b ; do
    setfont "${font}" >/dev/null 2>&1
    if [ "${COLUMNS}" -ge 100 ]; then
      zdebug "set font to ${font}, screen is ${COLUMNS}x${LINES}"
      break
    fi
  done
fi
