#!/usr/bin/env bash
# Local quality checks for the YASSM plugin.
# shellcheck enable=all
set -euo pipefail

cd -- "$(dirname -- "$0")"

omarchy plugin validate .

bash -n detect-gpu.sh temperature.sh

if command -v shellcheck >/dev/null 2>&1; then
	shellcheck --severity=warning detect-gpu.sh temperature.sh
fi

QML_LINT=/usr/lib/qt6/bin/qmllint

if [[ -x $QML_LINT ]]; then
	"$QML_LINT" \
		-I . \
		-I /usr/share/omarchy/shell \
		-I /usr/lib/qt6/qml \
		BarWidget.qml SettingsPanel.qml lib/SystemMetrics.qml lib/ThemePalette.qml
elif command -v qmllint >/dev/null 2>&1; then
	qmllint BarWidget.qml SettingsPanel.qml lib/SystemMetrics.qml lib/ThemePalette.qml
else
	echo "qmllint not found; skipping QML lint" >&2
fi
