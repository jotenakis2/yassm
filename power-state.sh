#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Battery timestamps: when the cable state and the charging state last changed.
# Stored in the user state dir so the tooltip keeps the right durations across
# shell restarts.
#
#   plugged <0|1>
#   plugged_since <epoch_ms>
#   charging_since <epoch_ms>   (0 when not charging)

state_dir=${XDG_STATE_HOME:-${HOME}/.local/state}/yassm
state_file=${state_dir}/power

case ${1:-read} in
read)
	[[ -r ${state_file} ]] || exit 0
	cat "${state_file}"
	;;
write)
	plugged=${2:-0}
	plugged_since=${3:-0}
	charging_since=${4:-0}

	mkdir -p "${state_dir}"
	printf 'plugged %s\nplugged_since %s\ncharging_since %s\n' \
		"${plugged}" "${plugged_since}" "${charging_since}" >"${state_file}"
	;;
*)
	printf 'usage: %s [read|write <0|1> <plugged_ms> <charging_ms>]\n' "$0" >&2
	exit 2
	;;
esac
