#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# The first pacman transaction is the installation itself (Omarchy is
# Arch-based), which is more precise than a file timestamp.
first=$(head -n 1 /var/log/pacman.log 2>/dev/null || true)

if [[ $first =~ ^\[([0-9]{4}-[0-9]{2}-[0-9]{2})T ]]; then
	printf '%s\n' "${BASH_REMATCH[1]}"
	exit 0
fi

# Fallback: birth time of the root filesystem (btrfs, ext4, xfs).
stamp=$(stat -c %W / 2>/dev/null || true)

if [[ $stamp =~ ^[0-9]+$ ]] && ((stamp > 0)); then
	date -d "@$stamp" +%Y-%m-%d
	exit 0
fi

# Unknown: print an empty line so the caller simply skips the field.
printf '\n'
