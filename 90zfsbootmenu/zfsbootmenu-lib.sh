#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# ZFS boot menu functions

# arg1: ZFS filesystem name
# prints: mountpoint
# returns: 0 on success

mount_zfs() {
  local fs mnt ret

  fs="${1}"

  mnt="${BASE}/${fs}/mnt"
  test -d "${mnt}" || mkdir -p "${mnt}"

  # zfsutil is required for non-legacy mounts and omitted for legacy mounts
  if [ "x$(zfs get -H -o value mountpoint "${fs}")" = "xlegacy" ]; then
    mount -t zfs "${fs}" "${mnt}"
    ret=$?
  else
    mount -o zfsutil -t zfs "${fs}" "${mnt}"
    ret=$?
  fi

  echo "${mnt}"
  return ${ret}
}

# arg1: value to substitute for empty lines (default: "enter")
# prints: concatenated lines of stdin, joined by commas

# shellcheck disable=SC2120
csv_cat() {
  local CSV empty
  empty=${1:-enter}

  while read -r line; do
    if [ -z "$line" ]; then
      line="${empty}"
    fi
    CSV+=("${line}")
  done
  (IFS=',' ; printf '%s' "${CSV[*]}")
}

# arg1: Path to file with detected boot environments, 1 per line
# prints: key pressed, boot environment
# returns: 130 on error, 0 otherwise

draw_be() {
  local env selected ret

  env="${1}"

  test -f "${env}" || return 130

  selected="$( ${FUZZYSEL} -0 --prompt "BE > " \
    --expect=alt-k,alt-d,alt-s,alt-c,alt-r,alt-p \
    --preview-window="up:${PREVIEW_HEIGHT}" \
    --header="[ENTER] boot [ALT+K] kernel [ALT+D] set bootfs [ALT+S] snapshots [ALT+C] cmdline [ALT+P] Pool status" \
    --preview="zfsbootmenu-preview.sh ${BASE} {} ${BOOTFS}" < "${env}" )"
  ret=$?
  # shellcheck disable=SC2119
  csv_cat <<< "${selected}"
  return ${ret}
}

# arg1: ZFS filesystem name
# prints: bootfs, kernel, initramfs
# returns: 130 on error, 0 otherwise

draw_kernel() {
  local benv selected ret

  benv="${1}"

  selected="$( ${FUZZYSEL} --prompt "${benv} > " --tac --expect=alt-d \
    --with-nth=2 --header="[ENTER] boot [ALT+D] set default [ESC] back" \
    --preview-window="up:${PREVIEW_HEIGHT}" \
    --preview="zfsbootmenu-preview.sh ${BASE} ${benv} ${BOOTFS}" < "${BASE}/${benv}/kernels" )"
  ret=$?
  # shellcheck disable=SC2119
  csv_cat <<< "${selected}"
  return ${ret}
}

# arg1: ZFS filesystem name
# prints: selected snapshot
# returns: 130 on error, 0 otherwise

draw_snapshots() {
  local benv selected ret

  benv="${1}"

  selected="$( zfs list -t snapshot -H -o name "${benv}" |
    ${FUZZYSEL} --prompt "Snapshot > " --tac --expect=alt-x,alt-c,alt-d \
      --preview="zfsbootmenu-preview.sh ${BASE} ${benv} ${BOOTFS}" \
      --preview-window="up:${PREVIEW_HEIGHT}" \
      --header="[ENTER] duplicate [ALT+X] clone and promote [ALT+C] clone only [ALT+D] show diff [ESC] back" )"
  ret=$?
  # shellcheck disable=SC2119
  csv_cat <<< "${selected}"
  return ${ret}
}

# arg1: ZFS snapshot
# arg2: ZFS filesystem
# prints: nothing
# returns: nothing

draw_diff() {
  local snapshot diff_target mnt

  snapshot="${1}"
  pool="${snapshot%%/*}"

  if set_rw_pool "${pool}"; then
    CLEAR_SCREEN=1
    key_wrapper "${pool}"
    CLEAR_SCREEN=0
  else
    return
  fi

  diff_target="${snapshot%%@*}"
  if ! mnt="$( mount_zfs "${diff_target}" )" ; then
    return
  fi

  # shellcheck disable=SC2016
  ( zfs diff -H "${snapshot}" "${diff_target}" & echo $! >&3 ) 3>/tmp/diff.pid | \
    sed "s,${mnt},," | \
    ${FUZZYSEL} --prompt "Files > " \
      --preview="zfsbootmenu-preview.sh ${BASE} ${diff_target} ${BOOTFS}" \
      --preview-window="up:${PREVIEW_HEIGHT}" \
      --bind 'esc:execute-silent( kill $( cat /tmp/diff.pid ) )+abort'

  test -f /tmp/diff.pid  && rm /tmp/diff.pid
  umount "${mnt}"
  return
}

# arg1: nothing
# prints: selected pool
# returns: 130 on error, 0 otherwise

draw_pool_status() {
  local selected ret

  selected="$( zpool list -H -o name |
    ${FUZZYSEL} --prompt "Pool > " --tac --expect=alt-r \
    --preview="zpool status -v {}" \
    --header="[ALT+R] Rewind checkpoint [ESC] back" \
  )"
  ret=$?
  csv_cat <<< "${selected}"
  return ${ret}
}


# arg1: bootfs kernel initramfs
# prints: nothing
# returns: 1 on error, otherwise does not return

kexec_kernel() {
  local selected fs kernel initramfs

  selected="${1}"

  tput clear

  # zfs filesystem
  # kernel
  # initramfs
  IFS=' ' read -r fs kernel initramfs <<<"${selected}"

  mnt="$( mount_zfs "${fs}" )"

  ret=$?
  if [ $ret != 0 ]; then
    emergency_shell "unable to mount ${fs}"
    return 1
  fi

  cli_args="$( find_kernel_args "${fs}" "${mnt}" )"
  root_prefix="$( find_root_prefix "${fs}" "${mnt}" )"

  # restore kernel log level just before we kexec
  # shellcheck disable=SC2154
  echo "${printk}" > /proc/sys/kernel/printk

  kexec -l "${mnt}${kernel}" \
    --initrd="${mnt}${initramfs}" \
    --command-line="${root_prefix}${fs} ${cli_args}"

  umount "${mnt}"

  # Export if read-write, to ensure a clean pool
  pool="${selected%%/*}"
  if [ "$( zpool get -H -o value readonly "${pool}" )" = "off" ]; then
    export_pool "${pool}"
  fi

  kexec -e -i
}

# arg1: snapshot name
# arg2: new BE name
# prints: nothing
# returns: 0 on success

duplicate_snapshot() {
  local selected target recv_args

  selected="${1}"
  target="${2}"

  [ -n "$selected" ] || return 1
  [ -n "$target" ] || return 1

  pool="${selected%%/*}"

  set_rw_pool "${pool}" || return 1
  CLEAR_SCREEN=0
  key_wrapper "${pool}"
  CLEAR_SCREEN=1

  recv_args=( "-u" "-o" "canmount=noauto" "-o" "mountpoint=/" "${target}" )

  if command -v mbuffer >/dev/null 2>&1; then
    # Buffer the exchange when possible
    zfs send "${selected}" | mbuffer | zfs recv "${recv_args[@]}"
  else
    zfs send "${selected}" | zfs recv "${recv_args[@]}"
  fi
}

# arg1: snapshot name
# arg2: new BE name
# arg3: prevents promotion if equal to "nopromote"; otherwise ignored
# prints: nothing
# returns: 0 on success

clone_snapshot() {
  local selected target pool output opts parent

  selected="${1}"
  target="${2}"
  promote="${3}"

  [ -n "$selected" ] || return 1
  [ -n "$target" ] || return 1

  pool="${selected%%/*}"
  parent="${selected%%@*}"

  set_rw_pool "${pool}" || return 1
  key_wrapper "${pool}"

  while read -r PROPERTY VALUE
  do
    case "${PROPERTY}" in
      "mountpoint")
        # explicitly set in the clone
        ;;
      "canmount")
        # explicitly set in the clone
        ;;
      *)
        opts+=("-o" "${PROPERTY}=${VALUE}")
        ;;
    esac
  done <<< "$( zfs get -o property,value -s local,received -H all "${parent}" )"

  # Clone must succeed to continue
  zfs clone -o mountpoint=/ -o canmount=noauto "${opts[@]}" "${selected}" "${target}" || return 1

  if [ "x$promote" != "xnopromote" ]; then
    # Promotion must succeed to continue
    zfs promote "${target}" || return 1
  fi

  return 0
}

# arg1: ZFS filesystem
# arg2: default kernel path (omit to unset default)
# prints: nothing
# returns: 0 on success, 1 otherwise

set_default_kernel() {
  local fs kernel

  fs="$1"
  [ -n "${fs}" ] || return 1

  pool="${fs%%/*}"
  [ -n "${pool}" ] || return 1

  # Strip /boot/ to list only the file
  kernel="${2#/boot/}"

  # Make sure the pool is writable
  set_rw_pool "${pool}" || return 1
  CLEAR_SCREEN=1
  key_wrapper "${pool}"
  CLEAR_SCREEN=0

  # Restore nonspecific default when no kernel specified
  if [ -z "$kernel" ]; then
    zfs inherit org.zfsbootmenu:kernel "${fs}" || return 1
  else
    zfs set org.zfsbootmenu:kernel="${kernel}" "${fs}" || return 1
  fi

  return 0
}

set_default_env() {
  local selected pool output
  selected="${1}"

  pool="${selected%%/*}"

  set_rw_pool "${pool}" || return 1
  CLEAR_SCREEN=1
  key_wrapper "${pool}"
  CLEAR_SCREEN=0

  # shellcheck disable=SC2034
  if output="$( zpool set bootfs="${selected}" "${pool}" )"; then
    BOOTFS="${selected}"
  fi
}

# arg1: ZFS filesystem
# prints: nothing
# returns: 0 if kernels were found, 1 otherwise

find_be_kernels() {
  local fs mnt
  fs="${1}"


  local kernel kernel_base labels version kernel_records
  local defaults def_kernel def_kernel_file def_args def_args_file

  # Check if /boot even exists in the environment
  mnt="$( mount_zfs "${fs}" )"

  if [ ! -d "${mnt}/boot" ]; then
    umount "${mnt}"
    return 1
  fi

  # Make sure the kernel list starts fresh
  kernel_records="${mnt/mnt/kernels}"
  : > "${kernel_records}"

  # shellcheck disable=SC2012,2086
  for kernel in $( ls \
      ${mnt}/boot/{{vm,}linu{x,z},kernel}{,-*} 2>/dev/null | sort -V ); do
    # Pull basename and validate
    kernel=$( basename "${kernel}" )
    [ -e "${mnt}/boot/${kernel}" ] || continue

    # Kernel "base" extends to first hyphen
    kernel_base="${kernel%%-*}"
    # Kernel "version" is everything after base and may be empty
    version="${kernel#${kernel_base}}"
    version="${version#-}"

    # initramfs images can take many forms, look for a sensible one
    labels=( "$kernel" )
    if [ -n "$version" ]; then
      labels+=( "$version" )
    fi

    # Use a mess of loops instead better brace expansions to control priorities
    for ext in {.img,""}{"",.{gz,bz2,xz,lzma,lz4,lzo,zstd}}; do
      for pfx in initramfs initrd; do
        for lbl in "${labels[@]}"; do
          for i in "${pfx}-${lbl}${ext}" "${pfx}${ext}-${lbl}"; do
            if [ -e "${mnt}/boot/${i}" ]; then
              echo "${fs} /boot/${kernel} /boot/${i}" >> "${kernel_records}"
              break 4
            fi
          done
        done
      done
    done

  done

  defaults="$( select_kernel "${fs}" )"
  # shellcheck disable=SC2034
  IFS=' ' read -r def_fs def_kernel def_initramfs <<<"${defaults}"

  def_kernel_file="${mnt/mnt/default_kernel}"
  def_args_file="${mnt/mnt/default_args}"

  # If no default kernel is found, there are no kernels; leave the BE
  # directory in the same state it would be in had no /boot existed
  if [ -z "${def_kernel}" ]; then
    rm -f "${kernel_records}" "${def_kernel_file}" "${def_args_file}"
    return 1
  fi

  basename "${def_kernel}" > "${def_kernel_file}"

  def_args="$( find_kernel_args "${fs}" "${mnt}" )"
  echo "${def_args}" > "${def_args_file}"

  umount "${mnt}"
  return 0
}

# arg1: ZFS filesystem
# prints: fs kernel initramfs
# returns: nothing

select_kernel() {
  local zfsbe
  zfsbe="${1}"

  local specific_kernel kexec_args spec_kexec_args

  # By default, select the last kernel entry
  kexec_args="$( tail -1 "${BASE}/${zfsbe}/kernels" )"

  # If a specific kernel is listed, prefer it when possible
  specific_kernel="$( zfs get -H -o value org.zfsbootmenu:kernel "${zfsbe}" )"
  if [ "${specific_kernel}" != "-" ]; then
    while read -r spec_kexec_args; do
      local fs kernel initramfs
      IFS=' ' read -r fs kernel initramfs <<<"${spec_kexec_args}"
      if [[ "${kernel}" =~ ${specific_kernel} ]]; then
        kexec_args="${spec_kexec_args}"
        break
      fi
    done <<<"$( tac "${BASE}/${zfsbe}/kernels" )"
  fi

  echo "${kexec_args}"
}

# arg1: ZFS filesystem
# arg2: path for the mounted filesystem
# prints: discovered prefix for root= command-line argument

find_root_prefix() {
  local zfsbe_mnt zfsbe_fs prefix
  zfsbe_fs="${1}"
  zfsbe_mnt="${2}"

  # Grab the root prefix from a property if possible
  if prefix="$( zfs get -H -o value org.zfsbootmenu:rootprefix "${zfsbe_fs}" )"; then
    if [ "${prefix}" != "-" ]; then
      echo "${prefix}"
      return
    fi
  fi

  # Try looking at os-release in BE
  if [ -n "${zfsbe_mnt}" ]; then
    prefix=$(
      # OS type is in ID and ID_LIKE variables; /etc supersedes /usr/lib
      unset ID ID_LIKE
      for osrel in ${zfsbe_mnt}/{usr/lib,etc}/os-release; do
        if [ -f "${osrel}" ]; then
          # shellcheck disable=SC1090
          . "${osrel}" >/dev/null 2>&1
        fi
      done

      for ostype in $ID $ID_LIKE; do
        case "$ostype" in
          void|ubuntu|debian)
            echo "root=zfs:"
            break
            ;;
          arch)
            echo "zfs="
            break
            ;;
          *)
            ;;
        esac
      done
    )

    if [ -n "${prefix}" ]; then
      echo "${prefix}"
      return;
    fi
  fi

  # Just return a default
  echo "root=zfs:"
}

# arg1: ZFS filesystem
# arg2: path for a mounted filesystem
# prints: discovered kernel command line arguments
# returns: nothing

find_kernel_args() {
  local zfsbe_mnt zfsbe_fs zfsbe_def zfsbe_args zfsbe_noprop
  zfsbe_fs="${1}"
  zfsbe_mnt="${2}"

  # If there is an /etc/default in this BE, set it
  if [ -n "${zfsbe_mnt}" ] && [ -d "${zfsbe_mnt}/etc/default" ]; then
    zfsbe_def="${zfsbe_mnt}/etc/default"
  fi

  # Reasonable defaults if nothing specific is found
  zfsbe_args="quiet loglevel=3"

  if [ -f "${BASE}/default_args" ]; then
    # Prefer user override, if it exists
    zfsbe_args="$( head -1 "${BASE}/default_args" | tr -d '\n' )"
  elif [ -n "${zfsbe_fs}" ]; then
    # Otherwise, prefer ZFS property for this boot environment
    zfsbe_args="$( zfs get -H -o value org.zfsbootmenu:commandline "${zfsbe_fs}" )"
    if [ "x${zfsbe_args}" = "x-" ]; then
      zfsbe_noprop="yes"
    fi
  fi

  # With no override or property, look for files if they exist
  if [ -n "${zfsbe_noprop}" ] && [ -n "${zfsbe_def}" ]; then
    if [ -f "${zfsbe_def}/zfsbootmenu" ]; then
      zfsbe_args="$( head -1 "${zfsbe_def}/zfsbootmenu" | tr -d '\n' )"
    elif [ -f "${zfsbe_def}/grub" ]; then
      zfsbe_args="$(
        # shellcheck disable=SC1090
        . "${zfsbe_def}/grub";
        echo "${GRUB_CMDLINE_LINUX_DEFAULT}"
      )"
    fi
  fi

  # If noresume mode was selected, replace resume= arguments with noresume
  if [ -e "${BASE}/noresume" ]; then
    zfsbe_args="$( awk <<<"${zfsbe_args}" '
      BEGIN {
        quot = 0;
        supp = 0;
        ORS = " ";
      }

      {
        for (i=1; i <= NF; i++) {
          if ( quot == 0 ) {
            # If unquoted, determine if output should be suppressed
            if ( $(i) ~ /^resume=/ ) {
              # Argument starts with "resume=", suppress
              supp = 1;
            } else {
              # Nothing else is suppressed
              supp = 0;
            }
          }

          # If output is not suppressed, print the field
          if ( supp == 0 && length($(i)) > 0 ) {
            print $(i);
          }

          # If an odd number of quotes are in this field, toggle quoting
          if ( gsub(/"/, "\"", $(i)) % 2 == 1 ) {
            quot = (quot + 1) % 2;
          }
        }
        printf "noresume";
      }
    ' )"
  fi

  echo "${zfsbe_args}"
}

# no arguments
# prints: nothing
# returns: number of pools that can be imported

find_online_pools() {
  local importable pool state
  importable=()
  while read -r line; do
    case "$line" in
      pool*)
        pool="${line#pool: }"
        ;;
      state*)
        state="${line#state: }"
        if [ "${state}" == "ONLINE" ]; then
          importable+=("${pool}")
        fi
        ;;
    esac
  done <<<"$( zpool import )"
  (IFS=',' ; printf '%s' "${importable[*]}")
  return "${#importable[@]}"
}

# arg1: pool name
# prints: nothing
# returns: 0 on success, 1 on failure

import_pool() {
  local pool import_args

  pool="${1}"

  # Import /never/ mounts filesystems
  import_args=( "-N" )

  # shellcheck disable=SC2154
  if [ -n "${force_import}" ]; then
    import_args+=( "-f" )
  fi

  # shellcheck disable=SC2154
  if [ -n "${read_write}" ]; then
    import_args+=( "-o" "readonly=off" )
  else
    import_args+=( "-o" "readonly=on" )
  fi

  # shellcheck disable=SC2154
  if [ -n "${rewind_to_checkpoint}" ]; then
    import_args+=( "--rewind-to-checkpoint" )
  fi

  # shellcheck disable=SC2086
  status="$( zpool import "${import_args[@]}" ${pool} )"
  ret=$?

  return ${ret}
}

# arg1: pool name
# prints: nothing
# returns: 0 on success, 1 on failure

export_pool() {
  local pool
  pool="${1}"

  # shellcheck disable=SC2034
  status="$( zpool export "${pool}" )"
  ret=$?

  return ${ret}
}

# arg1: pool name
# prints: nothing
# returns: 0 on success, 1 on failure

rewind_checkpoint() {
  local pool checkpoint
  pool="${1}"

  while read -r line; do
    case "$line" in
      checkpoint*)
        checkpoint="${line#checkpoint: }"
        ;;
    esac
  done <<<"$( zpool status "${pool}" )"

  [ -z "${checkpoint}" ] && return 1

  selected="$( echo -e "Yes\nNo" | ${FUZZYSEL} \
    --header="Rewind checkpoint on ${pool} ?"
  )"

  [ "x${selected}" = "xYes" ] || return 1

  rewind_to_checkpoint=yes force_export=yes set_rw_pool "${pool}"
  return $?
}

# prints: nothing
# returns: 0 if suspend device found, 1 otherwise

has_resume_device() {
  # These partition types come from the dracut 95resume module
  for stype in suspend swsuspend swsupend; do
    if blkid -t TYPE="${stype}" >/dev/null 2>&1; then
      return 0
    fi
  done

  return 1
}

# arg1: pool name
# prints: nothing
# returns: 0 on success, 1 on failure

resume_prompt() {
  local pool

  pool="${1}"
  [ -n "${pool}" ] || return 1

  # Try to avoid importing writable when a resume device is found
  if has_resume_device; then
    # Make sure the warning is prominent
    tput clear
    tput cnorm
    tput cup 0 0

    cat <<-EOF
	WARNING!!!

	This system appears to have an active suspend partition.

	The action you are requesting requires the ZFS pool

	    ${pool}

	be imported read-write. Importing read-write and then resuming
	from an active suspend partition may DESTROY YOUR POOL.

	If you choose to proceed, ZFSBootMenu can attempt to remove any
	"resume=" arguments from your kernel command line and append a
	"noresume" argument to prevent your system from attempting to
	restore from the active suspend partition.

	Type NORESUME to proceed with the import, allowing ZFSBootMenu
	to add a "noresume" argument to your kernel command line.

	Type DANGEROUS to proceed with the import without allowing
	ZFSBootMenu to modify your kernel command line. Make sure to
	add the "noresume" argument yourself if necesary.

	Type any other text, or just press enter, to abort.

	Proceed [No] ?
	EOF

    read -r decision

    if [ "x${decision}" = "xDANGEROUS" ]; then
      return 0
    elif [ "x${decision}" = "xNORESUME" ]; then
      : > "${BASE}/noresume"
      return 0
    else
      return 1
    fi
  fi

  return 0
}

# arg1: pool name
# prints: nothing
# returns: 0 on success, 1 on failure

set_rw_pool() {
  local pool

  pool="${1}"
  [ -n "${pool}" ] || return 1

  # If force_export is set, skip evaluating if the pool is already read-write
  # shellcheck disable=SC2154
  [ -n "${force_export}" ] || [ "x$( zpool get -H -o value readonly "${pool}" )" = "xon" ] || return 0

  resume_prompt "${pool}" || return 1

  if export_pool "${pool}" ; then
    read_write=yes import_pool "${pool}"
    return $?
  fi

  return 1
}

# arg1: ZFS filesystem
# prints: name of encryption root, if present
# returns: 1 if key is needed, 0 if not

be_key_needed() {
  local fs pool encroot
  fs="${1}"
  pool="${fs%%/*}"

  if [ "$( zpool list -H -o feature@encryption "${pool}" )" == "active" ]; then
    encroot="$( zfs get -H -o value encryptionroot "${fs}" )"
    if [ "${encroot}" == "-" ]; then
      echo ""
      return 0
    else
      echo "${encroot}"
      return 1
    fi
  else
    echo ""
    return 0
  fi
}

# arg1: ZFS filesystem (encryption root)
# prints: nothing
# returns: 0 if unavailable, 1 if available

be_key_status() {
  local encroot keystatus
  encroot="${1}"

  keystatus="$( zfs get -H -o value keystatus "${encroot}" )"
  case "${keystatus}" in
    unavailable)
      return 0;
      ;;
    available)
      return 1;
      ;;
  esac
}

# arg1: ZFS filesystem (encryption root)
# prints: nothing
# returns: 0 on success, 1 on failure

load_key() {
  local encroot ret key keyformat keylocation
  encroot="${1}"

  keylocation="$( zfs get -H -o value keylocation "${encroot}" )"
  if [ "${keylocation}" = "prompt" ]; then
    if [ ${CLEAR_SCREEN} -eq 1 ] ; then
      tput clear
      tput cup 0 0
    fi
    zfs load-key -L prompt "${encroot}"
    ret=$?
  else
    key="${keylocation#file://}"
    keyformat="$( zfs get -H -o value keyformat "${encroot}" )"
    if [[ -f "${key}" ]]; then
      zfs load-key "${encroot}"
      ret=$?
    elif [ "${keyformat}" = "passphrase" ]; then
      if [ ${CLEAR_SCREEN} -eq 1 ] ; then
        tput clear
        tput cup 0 0
      fi
      zfs load-key -L prompt "${encroot}"
      ret=$?
    fi
  fi

  return ${ret}
}

# arg1: ZFS filesystem
# prints: nothing
# returns 0 on success, 1 on failure

key_wrapper() {
  local encroot fs ret
  fs="${1}"
  ret=0

  encroot="$( be_key_needed "${fs}" )"

  if [ $? -eq 1 ]; then
    if be_key_status "${encroot}" ; then
      if ! load_key "${encroot}" ; then
        ret=1
      fi
    fi
  fi

  return ${ret}
}

# arg1: path to BE list
# prints: nothing
# returns: 0 on success, 1 on failure

populate_be_list() {
  local be_list fs mnt active candidates

  be_list="${1}"
  [ -n "${be_list}" ] || return 1

  # Truncate the list to avoid stale entries
  : > "${be_list}"

  # Find valid BEs
  while IFS=$'\t' read -r fs mnt active; do
    if [ "x${mnt}" = "x/" ]; then
      # When mountpoint=/, BE is a candidate unless org.zfsbootmenu:active=off
      [ "x${active}" = "xoff" ] && continue
    elif [ "x${mnt}" = "xlegacy" ]; then
      # When mountpoint=legacy, BE is a candidate only if org.zfsbootmenu:active=on
      [ "x${active}" = "xon" ] || continue
    else
      # All other datasets are ignored
      continue
    fi
    candidates+=( "${fs}" )
  done <<< "$(zfs list -H -o name,mountpoint,org.zfsbootmenu:active)"

  for fs in "${candidates[@]}"; do
    # Unlock if necessary
    key_wrapper "${fs}" || continue

    # Candidates are added to BE list if they have kernels in /boot
    # shellcheck disable=SC2034
    if output="$( find_be_kernels "${fs}" )" ; then
      echo "${fs}" >> "${be_list}"
    fi
  done
  return 0
}


# arg1: message
# prints: nothing
# returns: nothing

emergency_shell() {
  local message
  message=${1:-unknown reason}

  tput clear
  tput cnorm

  echo -n "Launching emergency shell: "
  echo -e "${message}\n"
  /bin/bash
}
