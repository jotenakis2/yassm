#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

shopt -s nullglob

max=0
count=0

for path in /sys/class/thermal/thermal_zone*/temp /sys/class/hwmon/hwmon*/temp*_input; do
	[[ -r $path ]] || continue

	read -r raw <"$path" || continue

	[[ $raw =~ ^-?[0-9]+$ ]] || continue

	if (( raw > 0 && raw < 200000 )); then
		if (( raw > max )); then
			max=$raw
		fi
		count=$((count + 1))
	fi
done

printf '%d %d\n' "$max" "$count"
