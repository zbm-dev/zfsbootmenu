#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# shellcheck disable=SC1091
source /lib/zfsbootmenu-lib.sh

# zfsbootmenu-help invokes itself, so the value of $WIDTH depends
# on if $0 is launching fzf/sk (-L) or is being launched inside
# fzf/sk (-s).

WIDTH="$( tput cols )"
PREVIEW_SIZE="$(( WIDTH - 26 ))"
[ ${PREVIEW_SIZE} -lt 10 ] && PREVIEW_SIZE=10

[ -z "${FUZZYSEL}" ] && FUZZYSEL="fzf"

help_pager() {
  WANTED="${1}"

  SORTED=()
  for SECTION in "${SECTIONS[@]}"; do
    if ! [[ $SECTION =~ ${WANTED} ]]; then
      SORTED+=("${SECTION}")
    else
      FINAL="${SECTION}"
    fi
    done
  SORTED+=("${FINAL}")

  printf '%s\n' "${SORTED[@]}" | ${FUZZYSEL} \
    --prompt 'Topic > ' \
    --with-nth=2.. \
    --bind pgup:preview-up,pgdn:preview-down \
    --preview="$0 -s {1}" \
    --preview-window="right:${PREVIEW_SIZE}:wrap" \
    --header="$( colorize green "[ESC]" ) $( colorize lightblue "back" )" \
    --tac \
    --inline-info \
    --ansi
}

doc_base="/usr/share/docs/help-files"

# shellcheck disable=SC2012
for size in $( ls "${doc_base}" | sort -n -r ) ; do
  if [ "${PREVIEW_SIZE}" -ge "${size}" ]; then
    doc_path="${doc_base}/${size}"
    break
  fi
done

if [ -z "${doc_path}" ]; then
  # shellcheck disable=SC2012
  doc_path="${doc_base}/$( ls "${doc_base}" | sort -n | head -1 )"
fi

for pod in "${doc_path}"/* ; do
  desc="$( head -3 "${pod}" | grep zfsbootmenu )"
  # shellcheck disable=SC2206
  broken=(${desc//-/ })
  unset "broken[0]"
  SECTIONS+=( "${pod} ${broken[*]}" )
done

while getopts "lL:s:" opt; do
  case "${opt}" in
    l)
      printf '%s\n' "${SECTIONS[@]}"
      exit
      ;;
    L)
      help_pager "${OPTARG}"
      exit
      ;;
    s)
      # Skip the first three lines
      tail -n +3 "${OPTARG}"
      exit
      ;;
    ?)
      exit
      ;;
    *)
      exit
      ;;
  esac
done

# No options detected, show the main help section
help_pager "main-screen"
