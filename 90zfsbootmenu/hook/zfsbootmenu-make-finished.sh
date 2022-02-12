#!/bin/bash

# This exists because rd.hostonly=0 from release builds causes
# all of the finished initqueue directory to be destroyed.
# This short-circuits the execution of console_init, which
# breaks setting a keymap (amongst other things).

exec 2>/dev/null
INIT_FIN="/lib/dracut/hooks/initqueue/finished/"
mkdir "${INIT_FIN}" || exit 0
cat << EOF >> "${INIT_FIN}/99-zfsbootmenu-ready-chk.sh"
#!/bin/bash
test -f /zfsbootmenu/ready
EOF
chmod +x "${INIT_FIN}/99-zfsbootmenu-ready-chk.sh"
