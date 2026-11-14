#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Opens the command in a floating terminal (see the Hyprland rule for
# org.omarchy.yassm-command), then gives it the keyboard: without the focus the
# Enter prompt would never receive the key.

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
app_id=org.omarchy.yassm-command

omarchy-launch-or-focus-tui "--app-id=${app_id}" bash "${script_dir}/command-view.sh" "$@"

focus_window() {
	hyprctl dispatch "hl.dsp.focus({ window = \"class:${app_id}\" })" >/dev/null 2>&1 || true
}

sleep 1
focus_window
sleep 1
focus_window
