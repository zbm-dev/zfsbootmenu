#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

## This early-setup hook attempts to get a physical (non-serial) console
## to at least 100 columns. 

#shellcheck disable=SC1091
source /lib/zfsbootmenu-kcl.sh || exit 1
source /lib/kmsg-log-lib.sh || exit 1

if [ -z "${control_term}" ] && [ -f /etc/zfsbootmenu.conf ]; then
  #shellcheck disable=SC1091
  source /etc/zfsbootmenu.conf
fi

# Control terminal MUST be defined to proceed
[ -c "${control_term}" ] || exit 1

# Ensure that control_term is not a serial console
tty_re='/dev/tty[0-9]'
[[ ${control_term} =~ ${tty_re} ]] || exit 1

# rd.vconsole.font is consumed by the Dracut i18n module, which is forced to run before this hook
# If the user has specified a specific font/size, do not attempt to override it

if get_zbm_bool 1 zbm.autosize && ! font=$( get_zbm_arg rd.vconsole.font ) ; then
  cd /usr/share/zfsbootmenu/fonts/ || exit 0
  for font in ter-v32b ter-v28b ter-v24b ter-v20b ter-v14b ter-v12n; do
    [ -f "${font}.psf" ] && setfont "${font}.psf" >/dev/null 2>&1

    # 110 columns is the current minimum to show both the sort key and a note on the snapshot screen
    if [ "${COLUMNS}" -ge 110 ]; then
      zdebug "set font to ${font}, screen is ${COLUMNS}x${LINES}"
      break
    fi
  done
fi
