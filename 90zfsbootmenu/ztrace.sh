#!/bin/bash
#shellcheck disable=SC2086

r="\033[0;31m"
g="\033[0;32m"
o="\033[0;33m"
n="\033[0m"

while read -r line ; do
  time="${line:0:13}"
  suffix="${line:14:${#line}}"

  if [ "${suffix:0:3}" != "ZBM" ]; then
    continue
  fi

  IFS='|' read -r prefix trace log <<<"${suffix}"
  IFS=';' read -ra tokens <<<"${trace}"

  ppref="$( printf "%*s" 11 "${prefix}:" )"
  tpref="$( printf "%*s" 11 "trace:" )"

  pad=' '
  c="${g}"

  echo -e "${time} ${ppref} ${log}"
  for token in "${tokens[@]}" ; do
    IFS=',' read -r func file line <<<"${token}"
    echo -e "${time} ${tpref}${pad}${r}${func}@${c}${file}${n}#${line}"
    pad="${pad} "
    c="${o}"
  done

done < <( dmesg -T --time-format reltime -f user -l 7 ) | less -R -S +G
