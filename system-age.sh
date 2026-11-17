#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Prints four lines: the locale-aware short dates (e.g. "9 sept. 2026") and
# the matching Unix timestamps for the installation and for the last package
# upgrade. QML needs the timestamps to show ages in days without parsing a
# translated month name.
format_date() {
	local value=$1
	local formatted

	if formatted=$(date -d "${value}" +"%-d %b %Y" 2>/dev/null); then
		printf '%s\n' "${formatted}"
	else
		printf '\n'
	fi
}

# Last package upgrade: the most recent "[ALPM] starting full system upgrade"
# or "[ALPM] upgraded ..." line. Reading the log costs a few milliseconds and
# avoids guessing from a directory timestamp, which removals also touch.
print_update_date() {
	local last
	local value
	local stamp

	last=$(grep -E '^\[[0-9]{4}-[0-9]{2}-[0-9]{2}T[^]]+\] \[ALPM\] (starting full system upgrade|upgraded )' /var/log/pacman.log 2>/dev/null | tail -n 1 || true)

	if [[ ${last} =~ ^\[([0-9]{4}-[0-9]{2}-[0-9]{2})T ]]; then
		value=${BASH_REMATCH[1]}
		stamp=$(date -d "${value}" +%s 2>/dev/null || true)
		format_date "${value}"
		printf '%s\n' "${stamp}"
	else
		printf '\n\n'
	fi
}

# The first pacman transaction is the installation itself (Omarchy is
# Arch-based), which is more precise than a file timestamp.
first=$(head -n 1 /var/log/pacman.log 2>/dev/null || true)

if [[ ${first} =~ ^\[([0-9]{4}-[0-9]{2}-[0-9]{2})T ]]; then
	stamp=$(date -d "${BASH_REMATCH[1]}" +%s 2>/dev/null || true)
	format_date "${BASH_REMATCH[1]}"
	printf '%s\n' "${stamp}"
	print_update_date
	exit 0
fi

# Fallback: birth time of the root filesystem (btrfs, ext4, xfs).
stamp=$(stat -c %W / 2>/dev/null || true)

if [[ ${stamp} =~ ^[0-9]+$ ]] && ((stamp > 0)); then
	format_date "@${stamp}"
	printf '%s\n' "${stamp}"
	print_update_date
	exit 0
fi

# Unknown installation: keep the caller's four fields empty.
if [[ -r /var/log/pacman.log ]]; then
	printf '\n\n'
	print_update_date
else
	printf '\n\n\n\n'
fi
