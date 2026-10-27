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
		# hwmon paths are unreadable noise; keep the device name only.
		printf '%s\n' "${device:-hwmon}"
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
		zone=${path%/temp}
		printf '%s\n' "${zone##*/}"
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
declare -A seen_links=()
device_links=()

for path in /sys/class/hwmon/hwmon*/temp*_input; do
	[[ -r $path ]] || continue

	read -r raw <"$path" || continue
	[[ $raw =~ ^-?[0-9]+$ ]] || continue
	raw=$(normalize_raw "$raw")

	if (( raw > 0 && raw < 200000 )); then
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
		if [[ -e $dir/device && -z ${seen_links[$dir/device]:-} ]]; then
			seen_links[$dir/device]=1
			device_links+=("$dir/device")
		fi
	fi
done

# Resolving the device symlinks one by one used to fork readlink for every
# sensor (the bulk of this script's cost). One call handles them all.
if ((${#device_links[@]} > 0)); then
	mapfile -t device_targets < <(readlink -f -- "${device_links[@]}" 2>/dev/null || true)

	for device in "${device_targets[@]}"; do
		[[ -n $device ]] && hwmon_keys[${device##*/}]=1
	done
fi

for path in /sys/class/thermal/thermal_zone*/temp; do
	[[ -r $path ]] || continue

	read -r raw <"$path" || continue
	[[ $raw =~ ^-?[0-9]+$ ]] || continue
	raw=$(normalize_raw "$raw")

	if (( raw > 0 && raw < 200000 )); then
		label=$(sensor_label "$path")
		if [[ -n ${hwmon_keys[$label]:-} ]]; then
			continue
		fi
		printf '%d\t%s\n' "$raw" "$label"
	fi
done

# Fans travel with the same scan so no extra process is needed. A standing fan
# legitimately reports 0 rpm, so unlike temperatures the value is not filtered.
for path in /sys/class/hwmon/hwmon*/fan*_input; do
	[[ -r $path ]] || continue

	read -r rpm <"$path" || continue
	[[ $rpm =~ ^[0-9]+$ ]] || continue

	label_file="${path%_input}_label"
	label=""
	if [[ -r $label_file ]]; then
		IFS= read -r label <"$label_file" || true
	fi

	if [[ -z $label ]]; then
		dir=${path%/*}
		device=""
		if [[ -r $dir/name ]]; then
			IFS= read -r device <"$dir/name" || true
		fi
		label="${device:-hwmon} ${path##*/}"
		label=${label%_input}
	fi

	printf 'fan\t%d\t%s\n' "$rpm" "$label"
done
