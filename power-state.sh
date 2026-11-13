#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Battery cable state stamp: "plugged(0|1) epoch_ms" in the user state dir, so
# the tooltip can say how long the current state has lasted across restarts.

state_dir=${XDG_STATE_HOME:-${HOME}/.local/state}/yassm
state_file=${state_dir}/power

case ${1:-read} in
read)
	[[ -r ${state_file} ]] || exit 0
	cat "${state_file}"
	;;
write)
	plugged=${2:-0}
	stamp=${3:-0}
	mkdir -p "${state_dir}"
	printf '%s %s\n' "${plugged}" "${stamp}" >"${state_file}"
	;;
*)
	printf 'usage: %s [read|write <0|1> <epoch_ms>]\n' "$0" >&2
	exit 2
	;;
esac
