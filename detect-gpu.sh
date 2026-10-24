#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

emit() {
	printf '{"kind":"%s","path":"%s","command":"%s"}\n' "$1" "$2" "$3"
}

find_busy_percent() {
	local file

	while IFS= read -r -d '' file; do
		if [[ -r $file ]]; then
			emit "sysfs" "$file" ""
			return 0
		fi
	done < <(find /sys/class/drm -type f -name 'gpu_busy_percent' -print0 2>/dev/null | sort -z)

	return 1
}

if command -v nvidia-smi >/dev/null 2>&1; then
	emit "nvidia" "" "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits"
	exit 0
fi

if find_busy_percent; then
	exit 0
fi

# Aucune source fiable d'utilisation GPU. C'est notamment le cas sur Apple
# Silicon/Asahi : il n'existe pas d'outil `asahi-gpu-top`, donc le widget
# affiche « GPU --% » si le noyau n'expose pas gpu_busy_percent.
emit "none" "" ""
