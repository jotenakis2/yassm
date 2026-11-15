#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Print one /proc/<pid>/stat line per live process. The widget computes
# instantaneous deltas between two snapshots; a file-based snapshot avoids a
# second ps process and the lifetime-average %CPU that ps reports.
for stat in /proc/[0-9]*/stat; do
	[[ -r ${stat} ]] || continue
	printf '%s\n' "$(<"${stat}")"
done

# Owner of every pid, for the "you / root / others" summary in the tooltips.
# A single find is far cheaper than a stat or a status read per process.
printf '%s\n' "--uids--"
find /proc -maxdepth 1 -type d -name '[0-9]*' -printf '%f %U\n'
