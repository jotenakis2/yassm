#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

shopt -s nullglob

# The SMC exposes the whole-machine power rail; there is no per-CPU power
# counter on Apple Silicon. Printed with the frequencies so the CPU tooltip
# needs no extra process.
for file in /sys/class/hwmon/hwmon*/power*_input; do
	label_file="${file%_input}_label"
	[[ -r ${label_file} ]] || continue

	IFS= read -r label <"${label_file}" || continue
	[[ ${label} == "Total System Power" ]] || continue

	read -r watts <"${file}" || continue
	[[ ${watts} =~ ^[0-9]+$ ]] || continue

	printf 'power %s\n' "${watts}"
	break
done

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
