#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Print one /proc/<pid>/stat line per live process. The widget computes
# instantaneous deltas between two snapshots; a file-based snapshot avoids a
# second ps process and the lifetime-average %CPU that ps reports.
for stat in /proc/[0-9]*/stat; do
	[[ -r $stat ]] || continue
	printf '%s\n' "$(<"$stat")"
done
