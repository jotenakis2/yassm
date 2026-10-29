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

bash -n check.sh alerts.sh cpu-freq.sh deps.sh detect-gpu.sh disk-io.sh install-date.sh proc-snapshot.sh temperature.sh wifi-freq.sh

if command -v shellcheck >/dev/null 2>&1; then
	# Every script must pass all ShellCheck checks, including style ones.
	shellcheck --enable=all check.sh alerts.sh alerts-view.sh cpu-freq.sh deps.sh detect-gpu.sh disk-io.sh install-date.sh proc-snapshot.sh temperature.sh wifi-freq.sh
fi

# ---------------------------------------------------------------- metadata
manifest_version=$(python3 -c 'import json; print(json.load(open("manifest.json"))["version"])')
manifest_id=$(python3 -c 'import json; print(json.load(open("manifest.json"))["id"])')
readme_version=$(sed -n 's/^Version //p' README.md | head -n 1)
readme_fr_version=$(sed -n 's/^Version //p' README-fr.md | head -n 1)

[[ ${manifest_version} == "${readme_version}" ]] \
	|| fail "manifest version (${manifest_version}) != README.md version (${readme_version})"
[[ ${manifest_version} == "${readme_fr_version}" ]] \
	|| fail "manifest version (${manifest_version}) != README-fr.md version (${readme_fr_version})"
[[ ${manifest_id} == "$(basename "${PWD}")" ]] \
	|| fail "manifest id (${manifest_id}) != directory name ($(basename "${PWD}"))"

# ------------------------------------------------------- script contracts
gpu_json=$(./detect-gpu.sh)

if command -v jq >/dev/null 2>&1; then
	printf '%s' "${gpu_json}" | jq -e '
		type == "object"
		and (.kind | type == "string")
		and (.path | type == "string")
		and (.command | type == "string")
	' >/dev/null || fail "detect-gpu.sh did not return the expected JSON object"
fi

./temperature.sh | awk -F'\t' '
	$1 == "fan" {
		if (NF != 3 || $2 !~ /^[0-9]+$/) exit 1
		next
	}
	NF != 2 { exit 1 }
' || fail "temperature.sh must print value/label pairs or fan<TAB>rpm<TAB>label"

# ---------------------------------------------------------------- qmllint
QML_LINT=/usr/lib/qt6/bin/qmllint

if [[ ! -x ${QML_LINT} ]]; then
	QML_LINT=$(command -v qmllint || true)
fi

[[ -n ${QML_LINT} ]] || fail "qmllint not found"

lint_version=$("${QML_LINT}" --version 2>&1 | head -n 1 || true)

if [[ ! ${lint_version} =~ ^qmllint\ 6\. ]]; then
	fail "Qt 6 qmllint is required (found: ${lint_version})"
fi

# qmllint resolves `import qs.Commons` as <root>/qs/Commons; Omarchy installs
# them as <root>/Commons. Mirror the expected layout in a temporary root so the
# Omarchy API is actually type-checked.
qml_root=$(mktemp -d "${TMPDIR:-/tmp}/yassm-qml.XXXXXX")
trap 'rm -rf "$qml_root"' EXIT

mkdir -p "${qml_root}/qs"
ln -s /usr/share/omarchy/shell/Commons "${qml_root}/qs/Commons"
ln -s /usr/share/omarchy/shell/Ui "${qml_root}/qs/Ui"

# The lib singletons only use Qt and Omarchy APIs, which are resolvable with
# the temporary root above: they must stay completely warning-free.
lib_log=${qml_root}/lib.log
"${QML_LINT}" -I "${qml_root}" -I /usr/lib/qt6/qml \
	lib/I18n.qml lib/SystemMetrics.qml lib/ThemePalette.qml >"${lib_log}" 2>&1

if grep -q '^Warning:' "${lib_log}"; then
	cat "${lib_log}" >&2
	fail "qmllint reported warnings in lib/"
fi

# BarWidget and SettingsPanel depend on Quickshell types that have no
# qmltypes: their nested members (Style, ShellColor) and the PopupWindow
# anchor group cannot be type-checked. Every warning is expected to fall in
# those categories; anything else is a real issue and fails the check.
lint_log=${qml_root}/bar-widget.log
"${QML_LINT}" -I "${qml_root}" -I /usr/lib/qt6/qml \
	BarWidget.qml SettingsPanel.qml ThresholdRow.qml >"${lint_log}" 2>&1 || true

expected='Member "[A-Za-z]+" not found on type "QObject"|Could not find property "(window|adjustment|edges|gravity)"|unknown grouped property scope rect|Type rect is used but it is not resolved|no matching signal found for handler "onAnchoring"|id declarations are only allowed in objects'
unexpected=$(grep '^Warning:' "${lint_log}" | grep -vE "${expected}" || true)

if [[ -n ${unexpected} ]]; then
	printf '%s\n' "${unexpected}" >&2
	fail "qmllint reported unexpected warnings"
fi

warning_count=$(grep -c '^Warning:' "${lint_log}" || true)
printf 'qmllint: %s expected advisory warning(s) in the widgets (Quickshell qmltypes unavailable)\n' \
	"${warning_count}"
