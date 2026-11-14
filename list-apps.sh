#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Installed desktop entries as "id<TAB>Name" for the click-target picker.
# Hidden entries are skipped and the first copy found wins (user over system).

declare -A seen=()

IFS=: read -r -a data_dirs <<<"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

for dir in "${XDG_DATA_HOME:-${HOME}/.local/share}/applications" "${data_dirs[@]/%//applications}"; do
	[[ -d ${dir} ]] || continue

	for file in "${dir}"/*.desktop; do
		[[ -r ${file} ]] || continue

		base=$(basename "${file}" .desktop)
		[[ -n ${seen[${base}]:-} ]] && continue
		seen[${base}]=1

		name=$(grep -m1 '^Name=' "${file}" | cut -d= -f2- || true)
		hidden=$(grep -m1 '^NoDisplay=' "${file}" | cut -d= -f2- || true)

		[[ ${hidden} == "true" ]] && continue
		[[ -z ${name} ]] && continue

		printf '%s\t%s\n' "${base}" "${name}"
	done
done | sort -t $'\t' -k 2
