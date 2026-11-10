#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

emit() {
	printf '{"kind":"%s","path":"%s","command":"%s","memory":"%s"}\n' "$1" "$2" "$3" "$4"
}

# The Apple GPU (Asahi) has no gpu_busy_percent, but it exposes its memory
# breakdown in sysfs. Report it for every kind so the tooltip can show it even
# when utilisation is unavailable.
find_memory() {
	local file

	for file in /sys/class/drm/card*/device/gpu_memory; do
		if [[ -r ${file} ]]; then
			printf '%s' "${file}"
			return 0
		fi
	done

	printf ''
}

# The Apple GPU publishes a cumulative busy counter, a power reading and a
# p-state in agx_stats; YASSM derives the utilisation from the counter.
find_agx_stats() {
	local file

	for file in /sys/class/drm/card*/device/agx_stats; do
		if [[ -r ${file} ]]; then
			printf '%s' "${file}"
			return 0
		fi
	done

	printf ''
}

memory=$(find_memory)

find_busy_percent() {
	local file

	# /sys/class/drm/cardN is a symlink. A plain `find` would not follow it,
	# so use the glob (which resolves symlinks) instead of `find -L`, whose
	# traversal of the sysfs symlink graph can block for a very long time.
	for file in /sys/class/drm/card*/device/gpu_busy_percent; do
		if [[ -r ${file} ]]; then
			emit "sysfs" "${file}" "" "${memory}"
			return 0
		fi
	done

	return 1
}

# Prefer the DRM sysfs counter: it is free and does not wake a runtime-
# suspended NVIDIA GPU. nvidia-smi remains the fallback when sysfs has no
# gpu_busy_percent (NVIDIA proprietary driver).
# The function signals "no counter" with its exit status; being in a
# condition is exactly the intent, so set -e must not apply to it.
# shellcheck disable=SC2310
if find_busy_percent; then
	exit 0
fi

if command -v nvidia-smi >/dev/null 2>&1; then
	emit "nvidia" "" "timeout 5 nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits" "${memory}"
	exit 0
fi

agx=$(find_agx_stats)

if [[ -n ${agx} ]]; then
	emit "agx" "${agx}" "" "${memory}"
	exit 0
fi

# Aucune source fiable d'utilisation GPU. C'est notamment le cas sur Apple
# Silicon/Asahi : il n'existe pas d'outil `asahi-gpu-top`, donc le widget
# affiche « GPU --% » si le noyau n'expose pas gpu_busy_percent. La mémoire,
# elle, reste disponible via gpu_memory.
emit "none" "" "" "${memory}"
