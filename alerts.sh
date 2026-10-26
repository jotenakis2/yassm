#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Alerts are deliberately conservative:
# - systemd units in the failed state (system and user managers);
# - zombies older than the threshold, to avoid flagging a process that is
#   already being reaped by its parent.
min_zombie_age=${YASSM_ZOMBIE_MIN_AGE:-60}
clk_tck=100

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

uptime_seconds=$(awk '{printf "%d", $1}' /proc/uptime)

for stat in /proc/[0-9]*/stat; do
	[[ -r $stat ]] || continue

	IFS= read -r line <"$stat" || continue
	[[ $line == *") "* ]] || continue

	rest=${line##*) }
	read -r -a fields <<<"$rest"
	[[ ${fields[0]:-} == Z ]] || continue

	pid=${line%% *}
	comm=${line#*(}
	comm=${comm%)*}
	start_ticks=${fields[19]:-}

	if [[ $start_ticks =~ ^[0-9]+$ ]]; then
		age=$((uptime_seconds - start_ticks / clk_tck))

		if ((age >= min_zombie_age)); then
			printf 'zombie\t%s\t%s\t%d\n' "$pid" "$comm" "$age"
		fi
	fi
done
