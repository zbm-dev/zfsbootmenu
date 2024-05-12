#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# Override control_term if executing over SSH
# shellcheck disable=SC2034
[ -n "${SSH_TTY}" ] && control_term="${SSH_TTY}"

# shellcheck disable=SC2016
fuzzy_default_options=(
  "--ansi" "--no-clear" "--cycle" "--color=16"
  "--layout=reverse-list" "--inline-info" "--tac"
  "--bind" '"alt-h:execute[ /libexec/zfsbootmenu-help -L ${HELP_SECTION:-main-screen} 1>/dev/null ]"'
  "--bind" '"ctrl-h:execute[ /libexec/zfsbootmenu-help -L ${HELP_SECTION:-main-screen} 1>/dev/null ]"'
  "--bind" '"ctrl-alt-h:execute[ /libexec/zfsbootmenu-help -L ${HELP_SECTION:-main-screen} 1>/dev/null ]"'
  "--bind" "\"alt-l:execute[ /bin/zlogtail 1>/dev/null ]${HAS_REFRESH:++refresh-preview}\""
  "--bind" "\"ctrl-l:execute[ /bin/zlogtail 1>/dev/null ]${HAS_REFRESH:++refresh-preview}\""
  "--bind" "\"ctrl-alt-l:execute[ /bin/zlogtail 1>/dev/null ]${HAS_REFRESH:++refresh-preview}\""
)

if [ -n "${HAS_BORDER}" ]; then
  # shellcheck disable=SC2016
  fuzzy_default_options+=(
    "--border-label-pos=top" "--border=top"
    "--color=border:white" "--separator=''"
  )
fi

# shellcheck disable=SC2016,SC2086
if [ ${loglevel:-4} -eq 7 ] ; then
  fuzzy_default_options+=(
    "--bind" '"alt-t:execute[ /sbin/ztrace > ${control_term} ]"'
    "--bind" '"ctrl-t:execute[ /sbin/ztrace > ${control_term} ]"'
    "--bind" '"ctrl-alt-t:execute[ /sbin/ztrace > ${control_term} ]"'
    "--bind" '"f12:execute[ /libexec/zfunc emergency_shell \"debugging shell\" > ${control_term} ]"'
  )
fi

export FUZZYSEL=fzf
export PREVIEW_HEIGHT=2
export FZF_DEFAULT_OPTS="${fuzzy_default_options[*]}"
