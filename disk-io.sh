#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Per-process storage I/O counters, one line per readable process:
#   pid <TAB> comm <TAB> read_bytes <TAB> write_bytes
# Only processes of the current user can be read; the rest are skipped.
# The widget turns the cumulative counters into rates between two samples.
for pid in /proc/[0-9]*; do
	[[ -r ${pid}/io ]] || continue

	r=0
	w=0

	while IFS=' ' read -r key value; do
		case ${key} in
		read_bytes:) r=${value} ;;
		write_bytes:) w=${value} ;;
		*) ;;
		esac
	done 2>/dev/null <"${pid}/io" || continue

	name=$(<"${pid}/comm") || continue

	printf '%s\t%s\t%s\t%s\n' "${pid##*/}" "${name}" "${r}" "${w}"
done
