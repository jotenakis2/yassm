#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Opened by the alerts click: the last hour of warnings/errors, then the units
# that are currently failed (system and user), then the zombie processes with
# the parent that is not reaping them. Kept in a pager so everything stays
# scrollable; less starts at the end, where the units and the zombies are.

# journalctl and systemctl only colorize on a tty; the report goes through a
# file for the pager, so ask systemd for colors explicitly.
export SYSTEMD_COLORS=1

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ ${LANG:-} == fr* ]]; then
	journal_title="journal : dernière heure, warning et au-dessus"
	system_title="unités systemd en échec : système"
	user_title="unités systemd en échec : utilisateur"
	zombie_title="processus zombie (pid, âge, parent)"
	zombie_none="aucun"
else
	journal_title="journal: last hour, warning and above"
	system_title="failed units: system"
	user_title="failed units: user"
	zombie_title="zombie processes (pid, age, parent)"
	zombie_none="none"
fi

# alerts.sh owns the thresholds and the ps walk; reuse it so the report and the
# tooltip always agree, and only reformat the zombie rows here.
zombies=$(
	"${script_dir}/alerts.sh" zombie 2>/dev/null | awk -F'\t' '
		function fmt(seconds) {
			if (seconds >= 3600) return sprintf("%dh %02dm", int(seconds / 3600), int((seconds % 3600) / 60))
			if (seconds >= 60) return sprintf("%dm", int(seconds / 60))
			return sprintf("%ds", seconds)
		}
		$1 == "zombie" {
			printf "%7s  %-20s %7s  ← %s %s\n", $2, $3, fmt($4), $5, $6
		}
	' || true
)

if [[ -z ${zombies} ]]; then
	zombies=${zombie_none}
fi

report=$(mktemp)
trap 'rm -f "${report}"' EXIT

{
	printf '== %s ==\n\n' "${journal_title}"
	journalctl -b -p warning --no-hostname --since=-1h --no-pager || true
	printf '\n== %s ==\n\n' "${system_title}"
	systemctl --failed --no-pager || true
	printf '\n== %s ==\n\n' "${user_title}"
	systemctl --failed --user --no-pager || true
	printf '\n== %s ==\n\n' "${zombie_title}"
	printf '%s\n' "${zombies}"
} >"${report}" 2>&1

less -R +G "${report}"
