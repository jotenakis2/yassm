#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

shopt -s nullglob

sum=0
count=0

for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
	[[ -r $file ]] || continue
	read -r value <"$file" || continue
	[[ $value =~ ^[0-9]+$ ]] || continue

	sum=$((sum + value))
	count=$((count + 1))
done

if ((count == 0)); then
	printf '0\n'
else
	printf '%d\n' "$((sum / count / 1000))"
fi
