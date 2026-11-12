#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Opened by the temperature click. The terminal closes as soon as this script
# exits, so it prints the report and waits for Enter.

# Take the keyboard before printing: the terminal maps behind the caller, so
# the Enter prompt below would otherwise never receive the key.
hyprctl dispatch 'hl.dsp.focus({ window = "class:org.omarchy.yassm-sensors" })' >/dev/null 2>&1 || true

if ! command -v sensors >/dev/null 2>&1; then
	if [[ ${LANG:-} == fr* ]]; then
		printf 'sensors est absent : installer le paquet lm_sensors.\n' >&2
	else
		printf 'sensors is missing: install the lm_sensors package.\n' >&2
	fi
else
	# An interactive shell colourises sensors through a grc alias, which a
	# script never inherits; call grc explicitly so the window looks the same.
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
fi

if [[ ${LANG:-} == fr* ]]; then
	printf '\nAppuyez sur Entrée pour fermer. '
else
	printf '\nPress Enter to close. '
fi

read -r _ || true
