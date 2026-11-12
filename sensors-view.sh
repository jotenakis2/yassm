#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Opened by the temperature click. The terminal is started with --hold, so the
# report stays on screen after this script exits; no pager is needed.

if ! command -v sensors >/dev/null 2>&1; then
	if [[ ${LANG:-} == fr* ]]; then
		printf 'sensors est absent : installer le paquet lm_sensors.\n' >&2
	else
		printf 'sensors is missing: install the lm_sensors package.\n' >&2
	fi
	exit 0
fi

# An interactive shell colourises sensors through a grc alias, which a script
# never inherits; call grc explicitly so the held window looks the same.
if command -v grc >/dev/null 2>&1; then
	sensors_cmd=(grc --colour=on sensors)
else
	sensors_cmd=(sensors)
fi

if ! "${sensors_cmd[@]}"; then
	if [[ ${LANG:-} == fr* ]]; then
		printf '\nsensors ne renvoie aucun capteur.\n' >&2
	else
		printf '\nsensors reported no sensors.\n' >&2
	fi
fi
