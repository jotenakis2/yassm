#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Alerts are deliberately conservative:
# - systemd units in the failed state (system and user managers);
# - zombies older than the threshold, to avoid flagging a process that is
#   already being reaped by its parent.
min_zombie_age=${YASSM_ZOMBIE_MIN_AGE:-60}

failed_units() {
	systemctl "$@" --failed --no-legend --plain --no-pager 2>/dev/null \
		| awk '{print $1}' || true
}

system_units=$(failed_units)
user_units=$(failed_units --user)

while IFS= read -r unit; do
	[[ -n $unit ]] && printf 'system\t%s\n' "$unit"
done <<<"$system_units"

while IFS= read -r unit; do
	[[ -n $unit ]] && printf 'user\t%s\n' "$unit"
done <<<"$user_units"

# ps walks /proc in C; doing the same loop in bash cost ~70 ms per run.
ps -eo pid=,stat=,etimes=,comm= | awk -v min_age="$min_zombie_age" '
	$2 ~ /^Z/ && $3 >= min_age {
		comm = $4
		for (i = 5; i <= NF; i++) comm = comm " " $i
		sub(/ <defunct>$/, "", comm)
		printf "zombie\t%s\t%s\t%d\n", $1, comm, $3
	}
' || true
