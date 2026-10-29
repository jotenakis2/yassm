#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

iface=${1:-}

# The associated frequency only exists while the interface is linked; print 0
# whenever it cannot be read so QML can simply skip the field.
# NetworkManager is already used for the SSID, so this avoids a second source.
if [[ -z ${iface} ]] || ! command -v nmcli >/dev/null 2>&1; then
	printf '0\n'
	exit 0
fi

freq=$(nmcli -t -f IN-USE,FREQ device wifi list ifname "${iface}" --rescan no 2>/dev/null | awk -F: '$1 == "*" { gsub(/[^0-9]/, "", $2); print $2; exit }' || true)

if [[ ! ${freq} =~ ^[0-9]+$ ]]; then
	printf '0\n'
	exit 0
fi

printf '%s\n' "${freq}"
