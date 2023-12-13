#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

## This early-setup hook attempts to get a physical (non-serial) console
## to at least 110 columns.

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

# Respect custom fonts set by the 'consolefont' mkinitcpio module
if [ -e /consolefont.psfu ] || [ -e /consolefont.psf ]; then
  exit 1
fi

# rd.vconsole.font is consumed by the Dracut i18n module, which is forced to run before this hook
# If the user has specified a specific font/size, do not attempt to override it

if get_zbm_bool 1 zbm.autosize && ! font=$( get_zbm_arg rd.vconsole.font ) ; then
  for font in /usr/share/zfsbootmenu/fonts/ter-v{{32,28,24,20,14}b,12n}.psf ; do
    [ -f "${font}" ] || continue
    setfont "${font}" >/dev/null 2>&1 || continue

    # 110 columns is the current minimum to show both the sort key and a note on the snapshot screen
    if [ "${COLUMNS}" -ge 110 ]; then
      zinfo "font set to ${font}, ${control_term} is ${COLUMNS}x${LINES}"
      break
    fi
  done
fi
