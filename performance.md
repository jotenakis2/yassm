# YASSM — Performance

**English** | [Français](performance-fr.md)

YASSM is a bar widget: it must stay invisible in `top` as much as on screen.
This page records how it was measured, what it costs, and why.

All numbers below were produced on the reference machine, idle, with no
tooltip open and the screensaver/locking disabled.

| | |
| --- | --- |
| Machine | Apple M2 Pro, 12 cores (aarch64) |
| OS | Omarchy 4.0.3 |
| Shell | Quickshell 0.3.2 |
| Kernel | 7.1.12 |
| YASSM | 1.21.x |

## TL;DR

- **No resident process.** Every helper script is transient.
- **Overhead ≈ 0.8 points of one core** (≈ 0.07 % of the machine's 12-core
  capacity) at the default 1 s refresh, dropping to ≈ 0.4 points at 5 s.
- **YASSM's absolute cost** when enabled is ≈ 1.4 points of one core
  (≈ 0.12 % of the machine), most of which is the 1 Hz bar update itself.
- **~15 script spawns per minute** when idle (temperature, disk, alerts,
  Wi-Fi frequency), and **0** for the CPU frequency outside its tooltip;
  while the CPU tooltip is open it runs every **2 × the Refresh interval**
  (2 s at the default 1 s, 10 s at 5 s).
- **Per-process disk I/O only runs while the DISK tooltip is open**
  (extended data): 13 ms per sample for ≈120 readable processes, every
  Processes interval, and nothing once the tooltip closes.
- **No battery polling**: UPower and NetworkManager are event-driven over
  D-Bus.

## How it was measured

### Shell process

CPU is the sum of the runtime of **every** thread of the `quickshell`
process, read from `/proc/<pid>/task/*/schedstat` (nanoseconds), not from the
main thread alone and not from `top`'s sampling. Wakeups are the sum of
`voluntary_ctxt_switches` and `nonvoluntary_ctxt_switches` in
`/proc/<pid>/status`.

Each state was sampled over two 90–120 s windows, alternating A/B, and
averaged. Alternating matters: the shell also runs other plugins and the
machine has background activity, so single windows drift by a few tenths of
a point.

```bash
pid=$(pgrep -x quickshell | head -1)
sum=0
for f in /proc/$pid/task/*/schedstat; do read -r v _ <"$f"; sum=$((sum + v)); done
echo "$sum"   # repeat after N seconds: CPU% = delta / (N * 1e9) * 100
```

### Scripts

Each script was run 10 times and its **child CPU time** (user + system) was
summed with Python's `os.times()`, which is more precise than wall-clock for
short-lived processes. Wall time was cross-checked with `hyperfine`.

```python
import os, subprocess
u = s = 0.0
for _ in range(10):
    before = os.times()
    subprocess.run(["./temperature.sh"], stdout=subprocess.DEVNULL)
    after = os.times()
    u += after.children_user - before.children_user
    s += after.children_system - before.children_system
print((u + s) / 10 * 1000, "ms CPU/run")
```

## Shell overhead

| Scenario | `quickshell` CPU (1 core) | Wakeups / min |
| --- | --- | --- |
| Without YASSM | 0.60 % | ~1 120 |
| With YASSM, 1 s refresh (default) | 1.20 % | ~1 950 |
| With YASSM, 5 s refresh | 0.80 % | ~1 680 |
| **Overhead at 1 s** | **+0.60 points** | **+830** |
| **Overhead at 5 s** | **+0.20 points** | **+560** |

The overhead is **0.05 % of the machine's total capacity** at 1 s
(0.60 points of one core out of 12 cores) and **0.017 %** at 5 s. For
reference, YASSM's absolute footprint when enabled is 1.20 % of one core,
i.e. 0.10 % of the machine.

The cost is dominated by the once-a-second update path: four `/proc` reads,
binding updates and text layout for the visible modules. That is why the
**Refresh** slider (1–5 s) has such a visible effect: at 5 s the shell drops
by a third.

Wakeups follow the same curve: +830/min at 1 s (≈ 14/s), +560/min at 5 s.

## Script costs

Idle state (no tooltip), reference machine:

| Script | CPU / run | Frequency | CPU / minute |
| --- | --- | --- | --- |
| `temperature.sh` (temperatures + fans) | 14 ms | 6×/min | 85 ms |
| `alerts.sh` (systemd + zombies) | 23 ms | 1×/min | 23 ms |
| `findmnt` (local filesystems) | 1 ms | 6×/min | 6 ms |
| `wifi-freq.sh` | 6 ms | 2×/min (wireless only) | 12 ms |
| Battery cycle count (`sysfs`) | < 1 ms | 1×/10 min | < 0.1 ms |
| **Total** | | | **≈ 126 ms/min** |

≈ 126 ms of CPU per minute is **0.21 % of one core** (0.018 % of the
machine). None of these processes stays alive between runs.

On demand only:

| Action | Cost | When |
| --- | --- | --- |
| `proc-snapshot.sh` × 2 | 11 ms each | CPU tooltip open (first snapshot + 1 s warmup) |
| `cpu-freq.sh` | 3 ms | CPU tooltip open, every 5 s |
| `ps -eo … rss` | ~15 ms | RAM tooltip open, every 5 s |
| `ip -4 -o addr` | 3 ms | each NET tooltip open |
| `wifi-freq.sh` | 6 ms | each NET tooltip open (wireless) |
| `/proc/net/wireless` | < 1 ms | each NET tooltip open (wireless) |
| `curl https://api.ipify.org` | one HTTPS request | NET tooltip open, at most every 5 min |
| `install-date.sh` | 3 ms | once at startup (Uptime tooltip) |
| `deps.sh` | 5 ms | once at startup (Settings warning) |

## Total

| Component | Points of one core | Share of the 12-core machine |
| --- | --- | --- |
| Shell update path (1 s) | +0.60 | 0.05 % |
| Idle scripts | +0.21 | 0.018 % |
| **Total overhead** | **≈ +0.8** | **≈ 0.07 %** |

At the 5 s refresh the total overhead falls to ≈ 0.4 points of one core
(≈ 0.03 % of the machine).

## Why it stays cheap

- **One sampler for the whole shell.** `lib/SystemMetrics.qml` is a singleton:
  multi-monitor setups share the same `/proc` reads and the same timers.
- **Module-aware sampling.** Every sampler is registered by reference list
  and only runs while at least one bar shows the module that consumes it. A
  hidden module stops its file reads and timers entirely.
- **On-demand details.** Process lists, CPU frequency, LAN/WAN addresses and
  PSI values used only by tooltips are fetched when the tooltip opens, not in
  the background. Frequency sampling stops as soon as the tooltip closes.
- **No polling where the system can push.** Battery state, health, SSID and
  link state come from UPower and NetworkManager over D-Bus.
- **Cheap paths for `/proc`.** Anything that can be a plain file read
  (`/proc/stat`, `meminfo`, `loadavg`, `net/dev`, `pressure/*`, `diskstats`,
  `uptime`, zswap state) is read with a `FileView`, with no process spawn.
- **Transient scripts, with timeouts.** `findmnt`, `ps`, `alerts.sh` and
  `temperature.sh` are wrapped in `timeout` so a dead network mount or a
  stuck systemd query cannot freeze the widget.
- **Scripts kept lean.** The temperature scan batches device symlink
  resolution in a single `readlink` call (30 ms → 14 ms), and `alerts.sh`
  scans zombies with `ps` + `awk` instead of a bash loop over `/proc`
  (82 ms → 23 ms).

## Accepted costs

- The 1 Hz refresh is the design point: a system monitor that updates once a
  second. Lowering it to 2 s or more in Settings cuts the shell overhead
  roughly proportionally.
- Opening the CPU tooltip costs two `/proc` snapshots 1 s apart (the first is
  only a baseline, because instantaneous CPU% needs a delta), plus a 3 ms
  frequency read.
- RSS is not reported here: the shell process is shared with every other
  plugin and its resident size fluctuates by more than YASSM's own footprint
  (a few MB of QML objects and one 20-line tooltip model), so any isolated
  number would be noise.
