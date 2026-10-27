#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

shopt -s nullglob

# One "cpu-index MHz" pair per core, in sysfs order. Kernels without cpufreq
# (most ARM servers, VMs) expose no file at all, so nothing is printed.
for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
	[[ -r ${file} ]] || continue

	read -r value <"${file}" || continue
	[[ ${value} =~ ^[0-9]+$ ]] || continue

	index=${file#/sys/devices/system/cpu/cpu}
	index=${index%%/*}

	printf '%s %d\n' "${index}" "$((value / 1000))"
done
