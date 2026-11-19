#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Associated Wi-Fi details while the link is up: frequency, SSID and signal,
# all from a single `iw` read (no root needed, no extra process per field).
# Key/value lines so the SSID may contain spaces; empty output means "no link".
#
# NetworkManager is still the fallback for the frequency: `iw` is not present
# everywhere and nmcli lists the frequency of the network in use.

iface=${1:-}
[[ -n ${iface} ]] || exit 0

if command -v iw >/dev/null 2>&1; then
	link=$(iw dev "${iface}" link 2>/dev/null || true)

	freq=$(awk '/^[[:space:]]*freq:/ { printf "%d\n", $2; exit }' <<<"${link}")
	ssid=$(sed -n 's/^[[:space:]]*SSID: //p' <<<"${link}" | head -n 1)
	signal=$(awk '/^[[:space:]]*signal:/ { printf "%d\n", $2; exit }' <<<"${link}")

	[[ -n ${ssid} ]] && printf 'ssid %s\n' "${ssid}"
	[[ -n ${freq} ]] && printf 'freq %s\n' "${freq}"
	[[ -n ${signal} ]] && printf 'signal %s\n' "${signal}"

	exit 0
fi

if command -v nmcli >/dev/null 2>&1; then
	freq=$(nmcli -t -f IN-USE,FREQ device wifi list ifname "${iface}" --rescan no 2>/dev/null \
		| awk -F: '$1 == "*" { gsub(/[^0-9]/, "", $2); print $2; exit }' || true)

	[[ ${freq} =~ ^[0-9]+$ ]] && printf 'freq %s\n' "${freq}"
fi
