#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# Override control_term if executing over SSH
# shellcheck disable=SC2034
[ -n "${SSH_TTY}" ] && control_term="${SSH_TTY}"

# shellcheck disable=SC2016
fuzzy_default_options=(
  "--ansi" "--no-clear" "--cycle"
  "--layout=reverse-list" "--inline-info" "--tac"
  "--color='16,current-fg:red,selected-fg:magenta'"
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

if [ -n "${HAS_RAW}" ] && is_efi_system ; then
  fuzzy_default_options+=(
    "--raw"
    "--gutter-raw"  '" "'
    "--pointer" '">"'
    "--marker" '"*"'
    "--bind" '"result:best"'
    "--bind" '"up:up-match"'
    "--bind" '"down:down-match"'
  )
fi

export FUZZYSEL=fzf
export PREVIEW_HEIGHT=2
export FZF_DEFAULT_OPTS="${fuzzy_default_options[*]}"
