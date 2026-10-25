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

# Sysfs prints plain decimal integers, but normalize anyway: bash arithmetic
# treats a leading zero as octal, which would silently corrupt a value such as
# 037300 into 15872.
normalize_raw() {
	local value=$1

	if [[ $value == -* ]]; then
		printf '%d' "-$((10#${value#-}))"
	else
		printf '%d' "$((10#$value))"
	fi
}

# hwmon devices and thermal zones frequently expose the same physical sensor
# (for example macsmc-battery). Collect the hwmon device names first, then skip
# thermal zones that carry the same label.
declare -A hwmon_keys=()

for path in /sys/class/hwmon/hwmon*/temp*_input; do
	[[ -r $path ]] || continue

	read -r raw <"$path" || continue
	[[ $raw =~ ^-?[0-9]+$ ]] || continue
	raw=$(normalize_raw "$raw")

	if (( raw != 0 && raw > -50000 && raw < 200000 )); then
		label=$(sensor_label "$path")
		printf '%d\t%s\n' "$raw" "$label"

		dir=${path%/*}
		if [[ -r $dir/name ]]; then
			IFS= read -r device <"$dir/name" || true
			if [[ -n $device ]]; then
				hwmon_keys[$device]=1
				hwmon_keys[${device//_/-}]=1
			fi
		fi
		if device=$(readlink -f "$dir/device" 2>/dev/null); then
			if [[ -n $device ]]; then
				hwmon_keys[${device##*/}]=1
			fi
		fi
	fi
done

for path in /sys/class/thermal/thermal_zone*/temp; do
	[[ -r $path ]] || continue

	read -r raw <"$path" || continue
	[[ $raw =~ ^-?[0-9]+$ ]] || continue
	raw=$(normalize_raw "$raw")

	if (( raw != 0 && raw > -50000 && raw < 200000 )); then
		label=$(sensor_label "$path")
		if [[ -n ${hwmon_keys[$label]:-} ]]; then
			continue
		fi
		printf '%d\t%s\n' "$raw" "$label"
	fi
done
