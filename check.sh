#!/usr/bin/env bash
# Local quality checks for the YASSM plugin.
# shellcheck enable=all
set -euo pipefail

cd -- "$(dirname -- "$0")"

fail() {
	printf 'check: %s\n' "$*" >&2
	exit 1
}

omarchy plugin validate .

bash -n check.sh alerts.sh cpu-freq.sh detect-gpu.sh proc-snapshot.sh temperature.sh wifi-freq.sh

if command -v shellcheck >/dev/null 2>&1; then
	shellcheck --severity=warning check.sh alerts.sh cpu-freq.sh detect-gpu.sh proc-snapshot.sh temperature.sh wifi-freq.sh
fi

# ---------------------------------------------------------------- metadata
manifest_version=$(python3 -c 'import json; print(json.load(open("manifest.json"))["version"])')
manifest_id=$(python3 -c 'import json; print(json.load(open("manifest.json"))["id"])')
readme_version=$(sed -n 's/^Version //p' README.md | head -n 1)
readme_fr_version=$(sed -n 's/^Version //p' README-fr.md | head -n 1)

[[ $manifest_version == "$readme_version" ]] \
	|| fail "manifest version ($manifest_version) != README.md version ($readme_version)"
[[ $manifest_version == "$readme_fr_version" ]] \
	|| fail "manifest version ($manifest_version) != README-fr.md version ($readme_fr_version)"
[[ $manifest_id == "$(basename "$PWD")" ]] \
	|| fail "manifest id ($manifest_id) != directory name ($(basename "$PWD"))"

# ------------------------------------------------------- script contracts
gpu_json=$(./detect-gpu.sh)

if command -v jq >/dev/null 2>&1; then
	printf '%s' "$gpu_json" | jq -e '
		type == "object"
		and (.kind | type == "string")
		and (.path | type == "string")
		and (.command | type == "string")
	' >/dev/null || fail "detect-gpu.sh did not return the expected JSON object"
fi

./temperature.sh | awk -F'\t' 'NF != 2 { exit 1 }' \
	|| fail "temperature.sh must print exactly one tab-separated pair per line"

# ---------------------------------------------------------------- qmllint
QML_LINT=/usr/lib/qt6/bin/qmllint

if [[ ! -x $QML_LINT ]]; then
	QML_LINT=$(command -v qmllint || true)
fi

[[ -n $QML_LINT ]] || fail "qmllint not found"

if ! "$QML_LINT" --version 2>/dev/null | grep -q '^qmllint 6\.'; then
	fail "Qt 6 qmllint is required (found: $("$QML_LINT" --version 2>&1 | head -n 1))"
fi

# qmllint resolves `import qs.Commons` as <root>/qs/Commons; Omarchy installs
# them as <root>/Commons. Mirror the expected layout in a temporary root so the
# Omarchy API is actually type-checked.
qml_root=$(mktemp -d "${TMPDIR:-/tmp}/yassm-qml.XXXXXX")
trap 'rm -rf "$qml_root"' EXIT

mkdir -p "$qml_root/qs"
ln -s /usr/share/omarchy/shell/Commons "$qml_root/qs/Commons"
ln -s /usr/share/omarchy/shell/Ui "$qml_root/qs/Ui"

# These two files only use Qt and Omarchy APIs. Two warnings are expected:
# - "pragma Singleton" is not declared in a qmldir (the directory is imported
#   as a namespace by the plugin);
# - UPower.devices is a dynamic list whose "values" member qmllint cannot see.
# More than two warnings means a new real issue.
"$QML_LINT" -I "$qml_root" -I /usr/lib/qt6/qml -W 2 \
	lib/SystemMetrics.qml lib/ThemePalette.qml

# BarWidget and SettingsPanel depend on Quickshell/Wayland types that have no
# qmltypes available; qmllint cannot type-check them. Keep it advisory and
# report the warning count instead of drowning the output.
lint_log=$qml_root/bar-widget.log
"$QML_LINT" -I "$qml_root" -I /usr/lib/qt6/qml \
	BarWidget.qml SettingsPanel.qml >"$lint_log" 2>&1 || true
warning_count=$(grep -c '^Warning:' "$lint_log" || true)
printf 'qmllint: %s advisory warning(s) in BarWidget.qml/SettingsPanel.qml (Quickshell types unavailable)\n' \
	"$warning_count"
