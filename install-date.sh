#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Prints two lines: the locale-aware short date (e.g. "9 sept. 2026") and the
# matching Unix timestamp. QML needs the timestamp to show the age in days
# without parsing a translated month name.
format_date() {
	local value=$1
	local formatted

	if formatted=$(date -d "${value}" +"%-d %b %Y" 2>/dev/null); then
		printf '%s\n' "${formatted}"
	else
		printf '\n'
	fi
}

# The first pacman transaction is the installation itself (Omarchy is
# Arch-based), which is more precise than a file timestamp.
first=$(head -n 1 /var/log/pacman.log 2>/dev/null || true)

if [[ ${first} =~ ^\[([0-9]{4}-[0-9]{2}-[0-9]{2})T ]]; then
	stamp=$(date -d "${BASH_REMATCH[1]}" +%s 2>/dev/null || true)
	format_date "${BASH_REMATCH[1]}"
	printf '%s\n' "${stamp}"
	exit 0
fi

# Fallback: birth time of the root filesystem (btrfs, ext4, xfs).
stamp=$(stat -c %W / 2>/dev/null || true)

if [[ ${stamp} =~ ^[0-9]+$ ]] && ((stamp > 0)); then
	format_date "@${stamp}"
	printf '%s\n' "${stamp}"
	exit 0
fi

# Unknown: two empty lines so the caller simply skips both fields.
printf '\n\n'
