#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

emit() {
	printf '{"kind":"%s","path":"%s","command":"%s"}\n' "$1" "$2" "$3"
}

find_busy_percent() {
	local file

	# /sys/class/drm/cardN is a symlink. A plain `find` would not follow it,
	# so use the glob (which resolves symlinks) instead of `find -L`, whose
	# traversal of the sysfs symlink graph can block for a very long time.
	for file in /sys/class/drm/card*/device/gpu_busy_percent; do
		if [[ -r $file ]]; then
			emit "sysfs" "$file" ""
			return 0
		fi
	done

	return 1
}

# Prefer the DRM sysfs counter: it is free and does not wake a runtime-
# suspended NVIDIA GPU. nvidia-smi remains the fallback when sysfs has no
# gpu_busy_percent (NVIDIA proprietary driver).
if find_busy_percent; then
	exit 0
fi

if command -v nvidia-smi >/dev/null 2>&1; then
	emit "nvidia" "" "timeout 5 nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits"
	exit 0
fi

# Aucune source fiable d'utilisation GPU. C'est notamment le cas sur Apple
# Silicon/Asahi : il n'existe pas d'outil `asahi-gpu-top`, donc le widget
# affiche « GPU --% » si le noyau n'expose pas gpu_busy_percent.
emit "none" "" ""
