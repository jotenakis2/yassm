#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

shopt -s nullglob

sensor_label() {
	local path=$1
	local label_file
	local label
	local dir
	local device

	case "$path" in
	/sys/class/hwmon/*/temp*_input)
		label_file="${path%_input}_label"
		if [[ -r $label_file ]]; then
			IFS= read -r label <"$label_file" || true
			if [[ -n $label && $label != "temp" ]]; then
				printf '%s\n' "$label"
				return
			fi
		fi
		dir=${path%/*}
		device=""
		if [[ -r $dir/name ]]; then
			IFS= read -r device <"$dir/name" || true
		fi
		printf '%s/%s/%s\n' "${device:-hwmon}" "${dir##*/}" "${path##*/}"
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

for path in /sys/class/thermal/thermal_zone*/temp /sys/class/hwmon/hwmon*/temp*_input; do
	[[ -r $path ]] || continue

	read -r raw <"$path" || continue

	[[ $raw =~ ^-?[0-9]+$ ]] || continue

	if (( raw > 0 && raw < 200000 )); then
		label=$(sensor_label "$path")
		printf '%d\t%s\n' "$raw" "$label"
	fi
done
