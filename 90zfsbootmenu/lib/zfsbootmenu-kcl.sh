#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# Include guard
[ -n "${_ZFSBOOTMENU_KCL}" ] && return
readonly _ZFSBOOTMENU_KCL=1

# args: none
# prints: tokenization of KCL [read from stdin]: one argument per line

kcl_tokenize() {
  awk '
    BEGIN {
      strt = 1;
      quot = 0;
    }

    {
      for (i=1; i <= NF; i++) {
        # If an odd number of quotes are in this field, toggle quoting
        if ( gsub(/"/, "\"", $(i)) % 2 == 1 ) {
          quot = (quot + 1) % 2;
        }

        # Print a space if this is not the start of a line
        if (strt == 0) {
          printf " ";
        }

        printf "%s", $(i);

        if (quot == 0) {
          strt = 1;
          printf "\n";
        } else {
          strt = 0;
        }
      }
    }
  '
}

# arg1: ZFS filesystem
# prints: value of org.zfsbootmenu:commandline, with %{parent} recursively expanded
# returns: 0 on success

read_kcl_prop() {
  local zfsbe args parfs par_args inherited

  zfsbe="${1}"
  if [ -z "${zfsbe}" ]; then
    zerror "zfsbe is undefined"
    return 1
  fi

  if ! args="$( zfs get -H -o value org.zfsbootmenu:commandline "${zfsbe}" )"; then
    zerror "unable to read org.zfsbootmenu:commandline on ${zfsbe}"
    return 1
  fi

  # KCL is empty, nothing to see
  if [ "${args}" = "-" ]; then
    zdebug "org.zfsbootmenu:commandline on ${zfsbe} has no value"
    echo ""
    return 0
  fi

  # KCL does not specify parent inheritance, just return the args
  if ! [[ "${args}" =~ "%{parent}" ]]; then
    zdebug "no parent reference in org.zfsbootmenu:commandline on ${zfsbe}"
    echo "${args}"
    return 0
  fi

  # Need to recursively expand "%{parent}"

  parfs="${zfsbe%/*}"
  if [ -z "${parfs}" ] || [ "${parfs}" = "${zfsbe}" ]; then
    # There is no parent, par_args is empty
    par_args=""
  else
    # Query the parent for KCL properties
    if ! par_args="$( read_kcl_prop "${parfs}" )"; then
      zwarn "failed to invoke read_kcl_prop on parent ${parfs}"
      par_args=""
    fi

    # When the KCL property is inherited, recursive expansion fully populates
    # the KCL at the level of the ancestor that actually defines the property.
    if inherited="$( zfs get -H -o source -s inherited org.zfsbootmenu:commandline "${zfsbe}" 2>/dev/null )"; then
      # Inherited property have a source of "inherited from <ancestor>";
      # non-inherited properties will not be printed with `-s inherited`
      if [ -n "${inherited}" ]; then
        zdebug "org.zfsbootmenu:commandline on ${zfsbe} is inherited, using parent expansion verbatim"
        echo "${par_args}"
        return 0
      fi
    fi
  fi

  echo "${args//%\{parent\}/${par_args}}"
  return 0
}

# arg1..argN: keys (and, optionally, associated value) to suppress from KCL
# prints: tokenized KCL [read from stdin] with suppressed arguments removed

kcl_suppress() {
  local arg rem sup
  while read -r arg; do
    # Check match against all exclusions
    sup=0
    for rem in "$@"; do
      # Arguments match entirely or up to first equal
      if [ "${arg}" = "${rem}" ] || [ "${arg%%=*}" = "${rem}" ]; then
        sup=1
        break
      fi
    done

    # Echo argument if it was not suppressed
    [ "${sup}" -ne 1 ] && echo "${arg}"
  done
}

# args1..argN: keys (and values, as appropriate) to append to a tokenized KCL
# prints: tokenized KCL [read from stdin] with appended arguments

kcl_append() {
  local arg

  # Carry forward input KCL
  cat

  # Append one line per argument
  for arg in "$@"; do
    echo "$arg"
  done
}


# args: none
# prints: space-separated concatenation of tokenized KCL [read from stdin]

kcl_assemble() {
  awk '
    BEGIN{ strt = 1; }

    {
      if (strt == 0) {
        printf " ";
      }

      printf "%s", $0;
      strt = 0;
    }
  '
}

# prints: contents of $BASE/zbm.cmdline, assembled as KCL

zbmcmdline() {
  [ -r "${BASE}/zbm.cmdline" ] && kcl_assemble < "${BASE}/zbm.cmdline"
  echo 
}
