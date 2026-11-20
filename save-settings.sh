#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Snapshot of this widget's settings, so a bar layout accident (the widget
# removed from shell.json) can be undone with restore-settings.sh. One
# argument: the entry as JSON. Written atomically: a crash mid-write must not
# leave a truncated snapshot behind.

state_dir=${XDG_STATE_HOME:-${HOME}/.local/state}/yassm

[[ ${#} -eq 1 && -n ${1:-} ]] || exit 2

mkdir -p "${state_dir}"

tmp=${state_dir}/settings.json.$$
printf '%s\n' "$1" >"${tmp}"
mv "${tmp}" "${state_dir}/settings.json"
