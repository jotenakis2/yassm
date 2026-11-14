#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Launches a desktop entry: terminal entries go through Omarchy's TUI launcher
# (which names its window after the command), everything else through
# gtk-launch inside a UWSM scope.

id=${1:-}
[[ -n ${id} ]] || exit 2

file=""
IFS=: read -r -a data_dirs <<<"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

for dir in "${XDG_DATA_HOME:-${HOME}/.local/share}/applications" "${data_dirs[@]/%//applications}"; do
	if [[ -r ${dir}/${id}.desktop ]]; then
		file=${dir}/${id}.desktop
		break
	fi
done

[[ -n ${file} ]] || exit 1

exec_line=$(grep -m1 '^Exec=' "${file}" | cut -d= -f2- || true)
terminal=$(grep -m1 '^Terminal=' "${file}" | cut -d= -f2- || true)

# Field codes (%f, %F, %U, …) only mean something to a file manager.
command=$(printf '%s' "${exec_line}" | sed -E 's/ ?%[a-zA-Z]//g')

if [[ ${terminal} == "true" && -n ${command} ]]; then
	read -r -a words <<<"${command}"
	exec omarchy-launch-tui "${words[@]}"
fi

exec uwsm-app -- gtk-launch "${id}.desktop"
