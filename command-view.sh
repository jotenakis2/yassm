#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Runs a click command inside its terminal and waits for Enter before the
# window closes, so long output stays readable.

if [[ $# -gt 0 ]]; then
	bash -lc "$*" || true
fi

if [[ ${LANG:-} == fr* ]]; then
	printf '\nAppuyez sur Entrée pour fermer. '
else
	printf '\nPress Enter to close. '
fi

read -r _ || true
