#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# kind|command|purpose. Only tools whose absence silently removes a feature
# are listed; btop and nvidia-smi are conveniences, not defects.
checks=(
	"required|awk|alerts and Wi-Fi frequency scripts"
	"required|date|installation date"
	"required|findmnt|disk module"
	"required|head|installation date"
	"required|ps|RAM process list and zombie scan"
	"required|readlink|temperature sensor names"
	"required|stat|installation date"
	"required|systemctl|Alerts module"
	"required|timeout|command guards"
	"optional|curl|public address in the NET tooltip"
	"optional|ip|LAN address in the NET tooltip"
	"optional|nmcli|Wi-Fi frequency in the NET tooltip"
)

for entry in "${checks[@]}"; do
	IFS='|' read -r kind name purpose <<<"${entry}"

	if ! command -v "${name}" >/dev/null 2>&1; then
		printf '%s\t%s\t%s\n' "${kind}" "${name}" "${purpose}"
	fi
done
