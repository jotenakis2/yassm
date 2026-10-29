#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Opened by the alerts click: the last hour of warnings/errors, then the units
# that are currently failed (system and user). Kept in a pager so everything
# stays scrollable; less starts at the end, where the failed units are.

if [[ ${LANG:-} == fr* ]]; then
	journal_title="journal : dernière heure, warning et au-dessus"
	system_title="unités systemd en échec : système"
	user_title="unités systemd en échec : utilisateur"
else
	journal_title="journal: last hour, warning and above"
	system_title="failed units: system"
	user_title="failed units: user"
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
} >"${report}" 2>&1

less -R +G "${report}"
