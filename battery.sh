#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

shopt -s nullglob

# AC adapter state: `online == 1` means the machine is plugged in, even when
# the battery itself is full or not charging.
online=0
for dir in /sys/class/power_supply/*; do
	[[ -r $dir/type ]] || continue

	read -r type <"$dir/type" || continue
	[[ $type == "Mains" ]] || continue

	if [[ -r $dir/online ]]; then
		value=0
		read -r value <"$dir/online" 2>/dev/null || value=0

		if [[ $value == "1" ]]; then
			online=1
		fi
	fi
done

for dir in /sys/class/power_supply/*; do
	[[ -r $dir/type ]] || continue

	read -r type <"$dir/type" || continue
	[[ $type == "Battery" ]] || continue

	present=1
	if [[ -r $dir/present ]]; then
		read -r present <"$dir/present" || present=1
	fi
	[[ $present == "1" ]] || continue

	capacity=""
	read -r capacity <"$dir/capacity" || capacity=""
	[[ $capacity =~ ^[0-9]+$ ]] || continue

	status=""
	read -r status <"$dir/status" || status=""

	time_empty=0
	if [[ -r $dir/time_to_empty_now ]]; then
		read -r time_empty <"$dir/time_to_empty_now" 2>/dev/null || time_empty=0
	fi

	time_full=0
	if [[ -r $dir/time_to_full_now ]]; then
		read -r time_full <"$dir/time_to_full_now" 2>/dev/null || time_full=0
	fi

	power=0
	if [[ -r $dir/power_now ]]; then
		read -r power <"$dir/power_now" 2>/dev/null || power=0
	fi

	printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$capacity" "$status" "$time_empty" "$time_full" "$power" "$online"
	exit 0
done
