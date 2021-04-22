#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

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
    --prompt 'Topic >' \
    --with-nth=2.. \
    --bind pgup:preview-up,pgdn:preview-down \
    --preview="$0 -s {1}" \
    --preview-window="right:${PREVIEW_SIZE}:wrap" \
    --header="$( colorize green "[ESC]" ) $( colorize lightblue "back" )" \
    --tac \
    --ansi \
    --color='border:6'
}

# shellcheck disable=SC2012
for size in $( ls help-files | sort -n -r ) ; do
  if [ "${PREVIEW_SIZE}" -gt "${size}" ]; then
    doc_path="help-files/${size}"
    break
  fi
done

if [ -z "${doc_path}" ]; then
  # shellcheck disable=SC2012
  doc_path="help-files/$( ls help-files | sort -n | head -1 )"
fi

for pod in "${doc_path}"/* ; do
  DESC="$( head -1 "${pod}" )"
  SECTIONS+=( "${pod} ${DESC}" )
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
      cat "${OPTARG}"
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
help_pager "main-menu"
