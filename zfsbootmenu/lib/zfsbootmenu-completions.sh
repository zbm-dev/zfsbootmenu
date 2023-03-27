#!/bin/bash
# shellcheck disable=SC2207

# disabling this allows completions with the @ character
shopt -u hostcomplete

_zfs-chroot() {
  local ZFS
  COMPREPLY=()

  [ "${#COMP_WORDS[@]}" != "2" ] && return

  for SNAP in $( zfs list -H -o name -t snapshot ) ; do
    ZFS+=("${SNAP}")
  done

  for FS in $( zfs list -H -o name ) ; do
    ZFS+=("${FS}")
  done

  COMPREPLY=( $( compgen -W "${ZFS[*]}" -- "${COMP_WORDS[1]}" ) )
}
complete -F _zfs-chroot zfs-chroot
complete -F _zfs-chroot zfs_chroot

_set_rw_pool() {
  local ZPOOL
  COMPREPLY=()

  [ "${#COMP_WORDS[@]}" != "2" ] && return

  for POOL in $( zpool list -H -o name ) ; do
    if ! is_writable "${POOL}" ; then
      ZPOOL+=("${POOL}")
    fi
  done
  COMPREPLY=( $( compgen -W "${ZPOOL[*]}" -- "${COMP_WORDS[1]}" ) )
}
complete -F _set_rw_pool set_rw_pool

_set_ro_pool() {
  local ZPOOL
  COMPREPLY=()

  [ "${#COMP_WORDS[@]}" != "2" ] && return

  for POOL in $( zpool list -H -o name ) ; do
    if is_writable "${POOL}" ; then
      ZPOOL+=("${POOL}")
    fi
  done
  COMPREPLY=( $( compgen -W "${ZPOOL[*]}" -- "${COMP_WORDS[1]}" ) )
}
complete -F _set_ro_pool set_ro_pool

_mount_zfs() {
  local ZFS
  COMPREPLY=()

  [ "${#COMP_WORDS[@]}" != "2" ] && return

  for SNAP in $( zfs list -H -o name -t snapshot ) ; do
    ZFS+=("${SNAP}")
  done

  for FS in $( zfs list -H -o name ) ; do
    ZFS+=("${FS}")
  done

  COMPREPLY=( $( compgen -W "${ZFS[*]}" -- "${COMP_WORDS[1]}" ) )
}
complete -F _mount_zfs mount_zfs

_zsnapshots() {
  local ZFS
  COMPREPLY=()

  [ "${#COMP_WORDS[@]}" != "2" ] && return

  for FS in $( zfs list -H -o name ) ; do
    ZFS+=("${FS}")
  done

  COMPREPLY=( $( compgen -W "${ZFS[*]}" -- "${COMP_WORDS[1]}" ) )
}
complete -F _zsnapshots zsnapshots

_zkexec() {
  local ARG index
  COMPREPLY=()

  shopt -s nullglob

  index="${#COMP_WORDS[@]}"
  case "${index}" in
    2)
      for FS in $( zfs list -H -o name ) ; do
        ARG+=("${FS}")
      done

      COMPREPLY=( $( compgen -W "${ARG[*]}" -- "${COMP_WORDS[1]}" ) )
    ;;
    3|4)
      mp="$( mount_zfs "${COMP_WORDS[1]}" )"
      [ -d "${mp}/boot" ] || return

      for BIN in "${mp}"/boot/* ; do
        BIN="${BIN##*/}"
        ARG+=("${BIN}")
      done
      umount "${mp}"
      COMPREPLY=( $( compgen -W "${ARG[*]}" -- "${COMP_WORDS[$(( index - 1))]}" ) )
    ;;
  esac

}
complete -F _zkexec zkexec

_mount_efivarfs() {
  local STATE
  COMPREPLY=()

  [ "${#COMP_WORDS[@]}" != "2" ] && return

  STATE=("ro" "rw")
  COMPREPLY=( $( compgen -W "${STATE[*]}" -- "${COMP_WORDS[1]}" ) )
}
complete -F _mount_efivarfs mount_efivarfs
