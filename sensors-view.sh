#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Opened by the temperature click: the full lm-sensors report, kept in a pager
# so nothing is lost when the terminal is shorter than the sensor list.

report=$(mktemp)
trap 'rm -f "${report}"' EXIT

sensors >"${report}" 2>&1 || true

if [[ ! -s ${report} ]]; then
	if [[ ${LANG:-} == fr* ]]; then
		printf 'sensors ne renvoie aucun capteur (paquet lm_sensors ?).\n' >"${report}"
	else
		printf 'sensors reported no sensors (lm_sensors package?).\n' >"${report}"
	fi
fi

less -R +G "${report}"
