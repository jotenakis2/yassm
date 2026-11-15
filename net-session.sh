#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Network session totals, kept across shell restarts but not across a reboot:
# the file records the boot id it belongs to, and `read` prints nothing when it
# does not match the running boot.

state_dir=${XDG_STATE_HOME:-${HOME}/.local/state}/yassm
state_file=${state_dir}/net-session
# Read straight into the variable: a `cat` here would cost a second process
# start for a 36-byte file, which is most of this script's runtime.
boot_id=""
IFS= read -r boot_id </proc/sys/kernel/random/boot_id || true

case ${1:-read} in
read)
	[[ -r ${state_file} ]] || exit 0
	read -r saved_boot saved_rx saved_tx <"${state_file}"

	[[ ${saved_boot} == "${boot_id}" ]] || exit 0

	printf '%s %s\n' "${saved_rx}" "${saved_tx}"
	;;
write)
	[[ -n ${boot_id} ]] || exit 1

	[[ -d ${state_dir} ]] || mkdir -p "${state_dir}"
	printf '%s %s %s\n' "${boot_id}" "${2:-0}" "${3:-0}" >"${state_file}"
	;;
*)
	printf 'usage: %s [read|write <rx_kb> <tx_kb>]\n' "$0" >&2
	exit 2
	;;
esac
