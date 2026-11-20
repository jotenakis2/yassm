#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Put the widget back on the bar and replay the settings saved by
# save-settings.sh. Safe to run when the widget is already there: `omarchy bar
# put` leaves an existing widget where it is, and each key is written through
# the shell's own config API.
#
#   bash restore-settings.sh [--dry-run]

id=io.github.jotenakis2.yassm
state_dir=${XDG_STATE_HOME:-${HOME}/.local/state}/yassm
snapshot=${state_dir}/settings.json
dry_run=false

[[ ${1:-} == "--dry-run" ]] && dry_run=true

[[ -r ${snapshot} ]] || {
	printf 'no snapshot at %s\n' "${snapshot}" >&2
	exit 1
}

command -v jq >/dev/null 2>&1 || {
	printf 'jq is required to read the snapshot\n' >&2
	exit 1
}

printf 'snapshot: %s\n' "${snapshot}"

if [[ ${dry_run} == true ]]; then
	jq -r 'to_entries[] | select(.key != "id") | "omarchy bar set '"${id}"' \(.key) \(.value | tojson) --json"' "${snapshot}"
	exit 0
fi

omarchy bar put "${id}" --section left --after omarchy.menu

rows=$(jq -r 'to_entries[] | select(.key != "id") | [.key, (.value | tojson)] | @tsv' "${snapshot}")

while IFS=$'\t' read -r key value; do
	[[ -n ${key} ]] || continue
	omarchy bar set "${id}" "${key}" "${value}" --json >/dev/null
done <<<"${rows}"

omarchy-restart-shell
printf 'restored %s\n' "${id}"
