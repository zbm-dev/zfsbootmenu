#!/bin/bash

check() {
  # We depend on udev-rules being loaded
  [ "${1}" = "-d" ] && return 0

  # Verify the zfs tool chain
  for tool in "/usr/bin/zpool" "/usr/bin/zfs" "/usr/bin/mount.zfs" ; do
    test -x "$tool" || return 1
  done
  # Verify grep exists
  command -v grep >/dev/null 2>&1 || return 1

  return 255
}

depends() {
  echo udev-rules
  return 0
}

installkernel() {
  instmods zfs
  instmods zcommon
  instmods znvpair
  instmods zavl
  instmods zunicode
  instmods zlua
  instmods icp
  instmods spl
  instmods zlib_deflate
  instmods zlib_inflate
}

install() {
  inst_rules /usr/lib/udev/rules.d/90-zfs.rules
  inst_rules /usr/lib/udev/rules.d/69-vdev.rules
  inst_rules /usr/lib/udev/rules.d/60-zvol.rules
  dracut_install hostid
  dracut_install /usr/bin/zfs
  dracut_install /usr/bin/zpool
  # Workaround for zfsonlinux/zfs#4749 by ensuring libgcc_s.so(.1) is included
  if ldd /usr/bin/zpool | grep -qF 'libgcc_s.so'; then
    # Dracut will have already tracked and included it
    :;
  elif command -v gcc-config >/dev/null 2>&1; then
    # On systems with gcc-config (Gentoo, Funtoo, etc.):
    # Use the current profile to resolve the appropriate path
    dracut_install "/usr/lib/gcc/$(s=$(gcc-config -c); echo "${s%-*}/${s##*-}")/libgcc_s.so.1"
  elif [[ -n "$(ls /usr/lib/libgcc_s.so* 2>/dev/null)" ]]; then
    # Try a simple path first
    dracut_install /usr/lib/libgcc_s.so*
  else
    # Fallback: Guess the path and include all matches
    dracut_install /usr/lib/gcc/*/*/libgcc_s.so*
  fi
  dracut_install /usr/bin/mount.zfs
  dracut_install /usr/lib/udev/vdev_id
  dracut_install /usr/lib/udev/zvol_id
  dracut_install tac
  dracut_install awk
  dracut_install basename
  dracut_install cut
  dracut_install head
  dracut_install kexec
  dracut_install fzf
  dracut_install mktemp
  dracut_install sort
  dracut_install sed
  dracut_install grep
  dracut_install xargs
  dracut_install clear
  dracut_install reset
  dracut_install lsblk
  dracut_install cut
  dracut_install tput
  dracut_install mount
  dracut_install df
  dracut_install ip
  dracut_install /usr/bin/mkdir
  dracut_install /usr/bin/tail
  dracut_install mbuffer
  dracut_install tr

  # shellcheck disable=SC2154
  inst_simple "${moddir}/zfsbootmenu-lib.sh" "/lib/zfsbootmenu-lib.sh"
  inst_simple "${moddir}/zfsbootmenu-preview.sh" "/bin/zfsbootmenu-preview.sh"
  inst_simple "${moddir}/zfs-chroot" "/bin/zfs-chroot"
  inst_hook cmdline 95 "${moddir}/zfsbootmenu-parse-commandline.sh"
  inst_hook pre-mount 90 "${moddir}/zfsbootmenu.sh"

  if [ -e /etc/zfs/zpool.cache ]; then
    inst /etc/zfs/zpool.cache
    type mark_hostonly >/dev/null 2>&1 && mark_hostonly /etc/zfs/zpool.cache
  fi

  if [ -e /etc/zfs/vdev_id.conf ]; then
    inst /etc/zfs/vdev_id.conf
    type mark_hostonly >/dev/null 2>&1 && mark_hostonly /etc/zfs/vdev_id.conf
  fi

  # Synchronize initramfs and system hostid
  AA=$(hostid | cut -b 1,2)
  BB=$(hostid | cut -b 3,4)
  CC=$(hostid | cut -b 5,6)
  DD=$(hostid | cut -b 7,8)

  # shellcheck disable=SC2154
  echo -ne "\\x${DD}\\x${CC}\\x${BB}\\x${AA}" > "${initdir}/etc/hostid"
}
