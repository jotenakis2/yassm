#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Opened by the temperature click: launch the sensors report, then give it the
# keyboard. The terminal maps behind the caller, so without this the Enter
# prompt would never receive the key.

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

omarchy-launch-or-focus-tui --app-id=org.omarchy.yassm-sensors bash "${script_dir}/sensors-view.sh"

focus_report() {
	hyprctl dispatch 'hl.dsp.focus({ window = "class:org.omarchy.yassm-sensors" })' >/dev/null 2>&1 || true
}

# The window needs a moment to map; a second pass covers slow terminals.
sleep 1
focus_report
sleep 1
focus_report
