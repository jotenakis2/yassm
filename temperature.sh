#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

shopt -s nullglob

sensor_label() {
	local path=$1
	local label_file
	local label

	case "$path" in
	/sys/class/hwmon/*/temp*_input)
		label_file="${path%_input}_label"
		if [[ -r $label_file ]]; then
			IFS= read -r label <"$label_file" || true
			if [[ -n $label ]]; then
				printf '%s\n' "$label"
				return
			fi
		fi
		printf '%s/%s\n' "${path%/*}" "${path##*/}"
		;;
	/sys/class/thermal/thermal_zone*/temp)
		label_file="${path%/temp}/type"
		if [[ -r $label_file ]]; then
			IFS= read -r label <"$label_file" || true
			if [[ -n $label ]]; then
				printf '%s\n' "$label"
				return
			fi
		fi
		printf '%s\n' "${path%/temp}"
		;;
	*)
		printf '%s\n' "$path"
		;;
	esac
}

max=0
count=0
max_path=""

for path in /sys/class/thermal/thermal_zone*/temp /sys/class/hwmon/hwmon*/temp*_input; do
	[[ -r $path ]] || continue

	read -r raw <"$path" || continue

	[[ $raw =~ ^-?[0-9]+$ ]] || continue

	if (( raw > 0 && raw < 200000 )); then
		if (( raw > max )); then
			max=$raw
			max_path=$path
		fi
		count=$((count + 1))
	fi
done

if (( max > 0 )); then
	label=$(sensor_label "$max_path")
else
	label=""
fi

printf '%d %d\t%s\n' "$max" "$count" "$label"
