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

if ! sensors; then
	if [[ ${LANG:-} == fr* ]]; then
		printf '\nsensors ne renvoie aucun capteur.\n' >&2
	else
		printf '\nsensors reported no sensors.\n' >&2
	fi
fi
