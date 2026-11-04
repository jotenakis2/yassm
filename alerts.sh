#!/usr/bin/env bash
# shellcheck enable=all
set -euo pipefail

# Alerts are deliberately conservative:
# - systemd units in the failed state (system and user managers);
# - zombies older than the threshold, to avoid flagging a process that is
#   already being reaped by its parent.
min_zombie_age=${YASSM_ZOMBIE_MIN_AGE:-60}

failed_units() {
	systemctl "$@" --failed --no-legend --plain --no-pager 2>/dev/null \
		| awk '{print $1}' || true
}

system_units=$(failed_units)
user_units=$(failed_units --user)

while IFS= read -r unit; do
	[[ -n ${unit} ]] && printf 'system\t%s\n' "${unit}"
done <<<"${system_units}"

while IFS= read -r unit; do
	[[ -n ${unit} ]] && printf 'user\t%s\n' "${unit}"
done <<<"${user_units}"

# ps walks /proc in C; doing the same loop in bash cost ~70 ms per run.
# PPID comes from the same table, and the parent name is resolved from it, so
# the report says who is not reaping the child. Fields after the four numbers
# are the command name: it may contain spaces, so the tail is joined back.
ps -eo pid=,ppid=,stat=,etimes=,comm= | awk -v min_age="${min_zombie_age}" '
	function joined(from,    text, i) {
		text = $from
		for (i = from + 1; i <= NF; i++) text = text " " $i
		return text
	}
	{
		count++
		proc_pid[count] = $1
		proc_ppid[count] = $2
		proc_stat[count] = $3
		proc_age[count] = $4
		proc_name[count] = joined(5)
	}
	END {
		for (i = 1; i <= count; i++) name_by_pid[proc_pid[i]] = proc_name[i]
		for (i = 1; i <= count; i++) {
			if (proc_stat[i] !~ /^Z/ || proc_age[i] < min_age) continue
			name = proc_name[i]
			sub(/ <defunct>$/, "", name)
			parent = name_by_pid[proc_ppid[i]]
			if (parent == "") parent = "?"
			printf "zombie\t%s\t%s\t%d\t%s\t%s\n", proc_pid[i], name, proc_age[i], proc_ppid[i], parent
		}
	}
' || true
