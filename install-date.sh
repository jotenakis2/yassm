#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Locale-aware short date, e.g. "9 sept. 2026" in French, "9 Sep 2026" in
# English. %-d drops the leading zero, %b follows LC_TIME.
format_date() {
	local value=$1
	local formatted

	if formatted=$(date -d "${value}" +"%-d %b %Y" 2>/dev/null); then
		printf '%s\n' "${formatted}"
	else
		printf '%s\n' "${value}"
	fi
}

# The first pacman transaction is the installation itself (Omarchy is
# Arch-based), which is more precise than a file timestamp.
first=$(head -n 1 /var/log/pacman.log 2>/dev/null || true)

if [[ ${first} =~ ^\[([0-9]{4}-[0-9]{2}-[0-9]{2})T ]]; then
	format_date "${BASH_REMATCH[1]}"
	exit 0
fi

# Fallback: birth time of the root filesystem (btrfs, ext4, xfs).
stamp=$(stat -c %W / 2>/dev/null || true)

if [[ ${stamp} =~ ^[0-9]+$ ]] && ((stamp > 0)); then
	format_date "@${stamp}"
	exit 0
fi

# Unknown: print an empty line so the caller simply skips the field.
printf '\n'
