#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

iface=${1:-}

# The associated frequency only exists while the interface is linked; print 0
# whenever it cannot be read so QML can simply skip the field.
if [[ -z ${iface} ]] || ! command -v iw >/dev/null 2>&1; then
	printf '0\n'
	exit 0
fi

freq=$(iw dev "${iface}" link 2>/dev/null | awk '/^[[:space:]]*freq:/ { print $2; exit }' || true)

if [[ ! ${freq} =~ ^[0-9]+([.][0-9]+)?$ ]]; then
	printf '0\n'
	exit 0
fi

printf '%d\n' "${freq%.*}"
