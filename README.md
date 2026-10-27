# YASSM — Yet Another Simple System Monitor

Version 1.25.5

**English** | [Français](README-fr.md)

Omarchy bar widget showing uptime, CPU, RAM, swap, system load, network,
temperature, GPU, battery, alerts and root partition usage.

Repository: <https://github.com/jotenakis2/yassm>

## Screenshots

![YASSM in the Omarchy bar](docs/screenshots/bar.png)

| Tooltips | |
| --- | --- |
| ![CPU](docs/screenshots/tooltip-cpu.png) | ![Memory](docs/screenshots/tooltip-memory.png) |
| ![Network](docs/screenshots/tooltip-net.png) | ![Sensors](docs/screenshots/tooltip-temp.png) |
| ![Swap](docs/screenshots/tooltip-swap.png) | ![Alerts](docs/screenshots/tooltip-alerts.png) |

<img src="docs/screenshots/settings.png" alt="Settings panel" width="380">

More in [`docs/screenshots`](docs/screenshots) (load, disk, battery, uptime).

## Modules

| Module | Source | Refresh |
| --- | --- | --- |
| CPU | `/proc/stat` | 1 s |
| RAM | `/proc/meminfo` (`MemAvailable`) | 1 s |
| Swap | `/proc/meminfo` (bar), `/proc/swaps` (5 s) + zram `mm_stat` (tooltip, 10 s) | 1 s |
| Load average | `/proc/loadavg`, normalized by CPU count, not capped at 100 % | 1 s |
| GPU | sysfs `gpu_busy_percent`, or `nvidia-smi` | 10 s |
| Disk | `findmnt` (root for the bar, local filesystems in the tooltip) | 10 s |
| Network | `/proc/net/dev` (default route, IPv4 then IPv6) | 1 s |
| Battery | UPower (D-Bus, event-driven) | immediate on event (~30 s otherwise) |
| Alerts | systemd failed units, zombies older than 60 s, root disk ≥ 95 %, RAM ≥ 95 % | 60 s (disk 10 s, RAM 1 s) |
| Uptime | `/proc/uptime`, shown as minutes or `hMM` | 5 s |
| Temperature | all normal temperatures, sorted | 10 s |

Swap is hidden when the machine has no active swap. The GPU shows `--%` when
no reliable source is available. The network is displayed in two separate
boxes, ↓ and ↑. CPU, RAM, swap, load and network share one fast loop, 1 s by
default and configurable from 1 to 5 s in Settings.

## Architecture

- `lib/SystemMetrics.qml` is a shared singleton: a single `/proc` sampler and a
  single `findmnt` for every bar instance, including multi-monitor setups.
  Battery data comes directly from UPower (event-driven).
- `SettingsPanel.qml` is loaded on demand on first open, then kept for
  subsequent openings. Its controls are Omarchy `Toggle`/`ToggleSwitch`,
  using the current theme's fonts, colors and spacing.
- GPU support remains handled by the widget, consistent with the current
  limitation of Asahi support.

## Requirements

**Required**

- Omarchy 4.x with its Quickshell shell.
- `bash` and coreutils (`date`, `head`, `readlink`, `stat`, `timeout`…).
- `awk` (POSIX).
- `findmnt` (util-linux) for the disk module.
- `ps` (procps-ng) for the RAM process list and the zombie scan.
- `systemctl` (systemd) when the Alerts module is enabled.
- `/proc`, `/sys` and a Nerd Font for the icons.

**Optional**

- `iw` — Wi-Fi frequency in the NET tooltip, only when the active link is
  wireless and extended data is on. Without it, the frequency is simply
  omitted.
- `ip` (iproute2) — LAN address in the extended NET tooltip.
- `curl` — public address in the extended NET tooltip (one HTTPS request to
  <https://api.ipify.org> at most every 5 minutes).
- `nvidia-smi` — NVIDIA GPU usage; the sysfs counter is preferred.
- `btop` — left-click launcher; without it the left click opens Settings.
- UPower and NetworkManager — battery details and SSID over D-Bus; without
  them those fields are hidden.

A missing optional tool never raises an error: the corresponding field is
omitted. The Settings panel shows a warning banner as soon as a required or
optional tool is missing; hovering it lists the exact tools and what they are
used for. `btop` and `nvidia-smi` are deliberately not flagged: they are
conveniences, and the GPU detector already falls back when no source exists.

The widget is designed for a horizontal bar (top or bottom). It is hidden on
vertical bars, where a `barSize`-wide slot cannot hold the module row.

## Installation

```bash
unzip yassm.zip -d "$HOME/.config/omarchy/plugins/"
omarchy plugin validate "$HOME/.config/omarchy/plugins/io.github.jotenakis2.yassm"
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.jotenakis2.yassm --section left
```

The last command places the widget in the bar's `left` section; adjust
`--section` (`left`, `center`, `right`) as you prefer.

## Settings panel

**Right-click** the widget to open the panel; **left-click** launches or
focuses `btop` when it is installed (Omarchy floats it at 875×600). If `btop`
is not installed, the left click opens the panel instead.

The panel lets you enable or disable each module, and reorder them by
dragging the handle on the left of each row (hover the MODULES header for the
hint). The order is applied to the bar
immediately and saved in `moduleOrder`.

Each section header carries a chevron: click it to collapse or expand that
section independently. Only **Modules** is expanded by default; the state is
kept for the session and is not written to `shell.json`.

**Language**: the tooltips and the settings panel follow the session locale —
French when it starts with `fr`, English for everything else. The labels
quoted in this page are the English ones; the French interface uses
`CAPTEURS`, `RÉSEAU`, `DÉMARRAGE`, `utilisation`, `cœurs`, `noyau`,
`ventilateurs`, and so on.

**Modules**

- Uptime
- CPU
- Load
- GPU
- Memory
- Swap
- Disk (`/`)
- Network
- Temperature
- Battery
- Alerts

**Layout**

- Boxes (module frames)
- Colors (colored thresholds and blue battery icon on mains)
- Extended data in tooltips (per-core CPU frequency, PSI, disk I/O, Wi-Fi, battery health)
- Between modules (gap between modules, 0–5 spaces; default 2)
- Between icon and value (gap between icon and value, 0–3 spaces; default 1)
- Processes shown (userland processes in tooltips, 1–20; default 10)

**Thresholds**

- Green from (default 40 °C)
- Orange from (default 50 °C)
- Red from (default 60 °C)

The three limits are editable number fields: type a value or use the arrows,
with one-degree steps; they are always kept in ascending order. Hover the
Green, Orange or Red label to read what that threshold changes.

**Timers**

- Refresh (metrics sampling interval, 1–5 s; default 1)
- Processes (tooltip process refresh, 2–10 s; default 5)

The **Between modules** slider sets the gap between modules from 0 to 5 spaces
(default 2). The **Between icon and value** slider sets the gap between each
module's icon and value from 0 to 3 spaces (default 1, i.e. 7.19 px). At 0, a
minimum gap of 2 px is kept.

The **Refresh** slider drives the fast loop (CPU, RAM, swap, load, network).
Network rates use the real elapsed time, so changing the interval does not
distort them. The **Processes** slider sets how often the CPU and RAM tooltips
refresh; it goes down to 2 s. The **Processes shown** slider caps the userland
list at 1–20 rows (default 10); the `kernel` line (extended data) is counted
separately. The CPU list is instantaneous (deltas from `/proc/<pid>/stat`),
while RAM uses RSS from `ps`. **Extended data in tooltips** adds per-core
frequencies, PSI, disk I/O, Wi-Fi details, LAN/WAN addresses, battery power
and health to their tooltips; it is on by default. Hovering any slider row
shows a tooltip with the same explanation. The panel scrolls
automatically if the screen is too short; Escape closes it.

Preferences are stored in `~/.config/omarchy/shell.json`, in the widget's bar
entry. There is no separate configuration file.

Example entry:

```json
{
  "id": "io.github.jotenakis2.yassm",
  "showCpu": true,
  "showMemory": true,
  "showSwap": true,
  "showGpu": true,
  "showBattery": true,
  "showTemp": true,
  "showLoad": true,
  "showDisk": true,
  "showNet": true,
  "showUptime": true,
  "showAlerts": true,
  "extendedTooltips": true,
  "showColors": true,
  "showBoxes": true,
  "spacing": 2,
  "iconGap": 1,
  "refreshInterval": 1,
  "processInterval": 5,
  "maxProcesses": 10,
  "tempWarm": 40,
  "tempHot": 50,
  "tempCritical": 60,
  "moduleOrder": [
    "uptime", "cpu", "load", "gpu", "memory", "swap",
    "disk", "net", "temp", "battery", "alerts"
  ]
}
```

All keys are optional; missing values use the defaults above. `moduleOrder`
is the list of module keys shown above (`net` covers both rate boxes); an
unknown key is dropped and a new module missing from the list is appended, so
an old `shell.json` never breaks the bar.

## Tooltips

Hovering a module shows a contextual tooltip:

- **Load**: raw 1, 5 and 15 minute load, followed by the CPU-normalised
  percentage in parentheses, in fixed columns (`1.43 ( 12%)`). The icon tilts
  with the load: needle low up to 50 %, medium from 51 to 90 %, high above
  that;
- **RAM**: the tooltip opens with a centered `data` heading, then shows
  `Total`, `Used` and `Available`. A centered `proc` heading introduces the
  top **userland** processes by RSS (up to the **Processes shown** value,
  default 10), grouped by name; the list refreshes every 5 s by default
  (2–10 s) while the tooltip stays open; kernel threads are excluded.
  Extended data adds `Shared` (`Shmem`: tmpfs and shared mappings, already
  counted in `Cached`), `Buffer` (`Buffers`), `Cache` (`Cached` +
  `SReclaimable`, like `free`; Buffer + Cache is the classic Buff/cache
  total), the `kernel` line (Slab − SReclaimable + stacks + page tables
  + vmalloc + percpu; SReclaimable is already in Cache, and vmalloc and
  percpu may slightly overlap) and a `pressure` section with `some`/`full`
  columns for the `10s`, `60s` and `300s` windows (`some`: at least one task
  stalled, `full`: no task making progress);
- **Swap**: used / total and the percentage. Extended data lists each
  swap device (zram included) with its own used / total and percentage under a
  `devices` heading, then a `zram` section (compressed size, original size,
  ratio and RAM used per device) and a `zswap` block (compressed size,
  original size, ratio) whenever zswap is enabled, even while its pool is
  empty;
- **Disk**: a `usage` section with one line per detected **local** filesystem,
  in GiB, with the percentage. Pseudo filesystems (`proc`, `sysfs`, `tmpfs`, `cgroup`, etc.)
  are ignored, along with ephemeral mounts under `/tmp` (AppImage, FUSE) and
  `/run/user`. Network filesystems (NFS, CIFS, SSHFS…) are skipped: querying
  their usage can block for seconds when the server is unreachable. Mount
  points that share the same device/source are deduplicated: on a btrfs root
  with subvolumes, `/home` and `/var/log` therefore do not appear separately
  from `/`. Extended data adds an `io` section (`R` read / `W` write rates),
  a `pressure` section (`some`/`full` for `10s`, `60s`, `300s`) and a `proc`
  section with the top processes by read/write rate (`R`/`W`, read from
  `/proc/<pid>/io`; only the user's processes are readable, and the sum does
  not rebuild the global rate because of writeback and root daemons);
- **Network**: an `io` section with download (↓) and upload (↑) rates plus
  the session total (deltas since the shell started, reset on restart and kept
  across interface changes), then an `interface` section with the interface name.
  Both rates are colored independently. The driver's absolute counter is not
  used because it can be bogus. Without a default route (loopback only), a red
  crossed-network icon and `--` replace both rates. Extended data completes
  the `interface` line with the LAN address (`ip -4`) and the public address
  (`curl`): `wlan0 · 192.168.50.148 · 90.29.68.78`. The heading uses the
  Wi-Fi icon only when the interface carrying the default route is wireless;
  in that case it also adds the SSID (from NetworkManager), the associated
  frequency (`iw`, e.g. `5500 MHz`) and the signal level (from
  `/proc/net/wireless`): `MaisonDuRuet · 5500 MHz · -67 dBm`;
- **Temperature**: the tooltip is titled `SENSORS`. A `temperatures` section
  lists every normal reading, sorted from highest to lowest, with the sensor
  name in parentheses; the bar shows the highest one. Labelled sensors keep
  their label, unlabeled hwmon sensors show the device name only
  (`macsmc_battery`, `tas2764`), and readings sharing a name are merged,
  keeping the hottest. The bar icon changes shape with the level while the
  value takes the level colour (thresholds on the rounded displayed value);
  with the defaults: snowflake below 40 °C, thermometer from 40 to 49 °C,
  heat wave from 50 to 59 °C, alert from 60 °C. All
  three thresholds are configurable in Settings → Thresholds. A `fans` section lists every
  hwmon fan with its speed in rpm (`Fan 1  0 rpm`), including standing fans at
  0;
- **Battery**: percentage, state, time remaining or time to full. Extended
  data adds the instantaneous power when UPower provides it, with an arrow
  (↓ while discharging, ↑ while charging), plus battery health and charge
  cycles;
- **CPU**: current percentage. The tooltip opens with a centered `cores`
  heading, then per-core percentages in two columns (split in half; three or
  more columns past 20 cores, at most 10 rows tall). A centered `proc`
  heading then introduces kernel CPU when extended data is on (`system` +
  `irq` + `softirq`), on the
  same scale as the processes, followed by the top **userland** processes by
  CPU (instantaneous deltas from `/proc/<pid>/stat`, scaled to total CPU
  capacity like the main value; up to **Processes shown**, default 10),
  grouped by name; when fewer processes are active, idle ones fill the
  remaining rows at 0.0%; the list refreshes every 5 s by default (2–10 s)
  while the tooltip stays open; kernel threads are excluded. Extended data
  adds a `pressure` section (CPU `some` only, since the kernel defines no
  `full` line for the CPU) and each core frequency in parentheses,
  right-aligned per column, sampled while the tooltip is open;
- **Uptime**: minutes below one hour (`42m`), then `3h42`; the tooltip shows
  `Time since boot : 3h 42m`. Extended data adds
  `Time since installation : 49 days` and `Installation date : 9 Sep 2026`
  (taken from the first `pacman` transaction, falling back to the root
  filesystem birth time; the month name follows the session locale);
- **GPU**: current percentage.

Tooltip titles (`CPU`, `RAM`, `NET`, `SENSORS`, etc.) and section headings
(`cores`, `data`, `pressure`, `proc`, `usage`, `io`, `devices`, `temperatures`,
`fans`, `zram`, `zswap`) are **bold** and use the tooltip text color; the body
uses the theme `muted` color. The `kernel` line in the CPU and RAM tooltips
(extended data only) is bold too, but keeps the body color. Network, swap,
disk and temperature tooltips launch no process. The RAM tooltip launches a
`ps` when it opens and every 5 s by default (2–10 s) while the hover lasts;
the CPU tooltip uses `/proc/<pid>/stat` snapshots instead.

## Bar colors

On the bar only, not in tooltips. Thresholds apply to the rounded displayed
value:

| Module | Normal | Green | Orange | Red |
| --- | --- | --- | --- | --- |
| CPU, RAM, Swap, GPU | < 10 % | 10–32 % | 33–65 % | ≥ 66 % |
| Disk | < 21 % | 21–32 % | 33–89 % | ≥ 90 % |
| Load | ≤ 10 % | 11–50 % | 51–90 % | > 90 % |
| Network | < 10 KiB/s | 10–499 KiB/s | 500–1000 KiB/s | > 1000 KiB/s |
| Battery | ≥ 50 % | 20–49 % | 11–19 % | ≤ 10 % |
| Temperatures (defaults) | < 40 °C | 40–49 °C | 50–59 °C | ≥ 60 °C |

Load is not capped: it can exceed 100 % when the run queue is longer than the
CPU count. Battery uses inverted logic: the lower the value, the more alarming
the color. Network download and upload rates are colored independently.

The green/orange/red colors come from the current Omarchy theme's
`colors.toml`. Icons keep the normal bar color, except for the battery icon:
as soon as the machine is on mains power (charging or held at a charge
threshold), the icon turns theme blue while the value keeps the normal bar
color. On battery, the value follows the thresholds above.

The disk value turns red at 90 %; the **Alerts** module only triggers at
95 % (disk or RAM). The temperature thresholds are defaults; the three
number fields in Settings → Thresholds change the green, orange and red
limits, to the degree. The **Colors** toggle
disables all these colors: values and the blue
battery icon return to the normal bar color. It maps to `showColors` in
`shell.json` (enabled by default).

## Battery icon

The icon follows the level in 10 % steps (empty icon at 0 %; 1–9 % shows the
10 % icon) and the power state:

- **on battery**: battery alone, filled according to the level;
- **charging**: battery with a bolt, blue icon, value in the normal bar color;
- **plugged but not charging** (full or charge threshold reached): battery
  followed by a plug, blue icon, value in the normal bar color.

The "plugged" state comes from `UPower.onBattery`, which distinguishes a
machine that is merely plugged in from one that is charging. Percentage,
state and power are provided by UPower properties: no script or timer is
needed, the bar reacts to D-Bus signals. UPower polls the hardware about every
30 s, so the percentage may change at that rate. Battery health comes from the
UPower battery device (the aggregate `DisplayDevice` leaves it empty); the
cycle count is read from sysfs (`/sys/class/power_supply/*/cycle_count`) once
at startup and every 10 minutes.

## Alerts

The **Alerts** module is enabled by default; it can be disabled in Settings. When
enabled, `alerts.sh` runs every 60 s and reports:

- systemd units in the `failed` state, for the system and user managers
  (red icon);
- zombies older than **60 s** (orange icon);
- the root filesystem at **95 % or more** (red icon), checked with the disk
  module every 10 s;
- RAM at **95 % or more** (red icon), checked with the memory module every
  second.

It appears at the far right, after Battery, with an icon only (no counter),
and only while at least one alert exists. The tooltip lists the failed units
under a centered lowercase `systemd` heading (server icon), then
`systemd --user` (user icon), then `proc zombie` (ghost icon), `disk` (disk
  icon) when the root is ≥ 95 %, and `ram` (memory icon) when RAM is ≥ 95 %; a
  blank line separates the sections. With
**Colors** disabled the icon uses the normal bar color. The Alerts toggle in
Settings has a hover tooltip explaining what the module reports.

## Uptime

The **Uptime** module is enabled by default and can be disabled in Settings.
It reads `/proc/uptime` every 5 s. The bar shows `42m` below one hour, then
`3h42`; the tooltip shows the same duration labelled `Time since boot`.
Extended data adds the age since installation in days and the distribution
installation date. `install-date.sh` resolves the date and its Unix timestamp
once at startup; the age is recomputed when the tooltip opens.

## Performance

Measured on the reference machine (Apple M2 Pro, 12 cores, Omarchy 4.0.3,
Quickshell 0.3.2), idle, no tooltip open. CPU is the sum of every `quickshell`
thread from `/proc/<pid>/task/*/schedstat`; each state is sampled over two
90–120 s windows and averaged.

| Scenario | `quickshell` CPU (1 core) | Wakeups / min |
| --- | --- | --- |
| Without YASSM | 0.60 % | ~1,120 |
| With YASSM, 1 s refresh | 1.20 % | ~1,950 |
| With YASSM, 5 s refresh | 0.80 % | ~1,680 |
| **Overhead at 1 s** | **+0.60 points** | **+830** |
| **Overhead at 5 s** | **+0.20 points** | **+560** |

The overhead is **0.05 % of the machine's total capacity** at the default 1 s
refresh (0.60 points of one core out of 12 cores); YASSM's absolute footprint
when enabled is 1.20 % of one core. The cost is dominated by the
once-a-second update path
(four `/proc` reads, binding updates, text layout), which is why the Refresh
slider has such a visible effect.

Short-lived scripts (CPU time per run, 10 runs each; none stays alive):

| Script | CPU / run | Frequency (idle) | CPU / minute |
| --- | --- | --- | --- |
| `temperature.sh` (temperatures + fans) | 14 ms | 6×/min | 85 ms |
| `alerts.sh` (systemd + zombies) | 23 ms | 1×/min | 23 ms |
| `findmnt` | 1 ms | 6×/min | 6 ms |
| `wifi-freq.sh` | 6 ms | 2×/min (wireless) + once per NET hover | 12 ms |
| Battery cycle count | <1 ms | 1×/10 min | <0.1 ms |
| **Total (idle)** | | | **~126 ms/min ≈ 0.21 % of one core** |

On demand only: `cpu-freq.sh` (3 ms) while the CPU tooltip is open,
`proc-snapshot.sh` (11 ms) while it is open, `ps` (~15 ms) while the RAM
tooltip is open, `ip` (3 ms) each time the NET tooltip opens, and the public
IP lookup at most every 5 minutes.

**Total idle cost ≈ 0.8 % of one core (≈0.07 % of the machine), no resident
process.** Module-aware sampling stops the reads and timers of hidden modules,
and the CPU frequency process only exists while its tooltip is open.

`findmnt` may wait ~100 ms on I/O for a network mount (`/media/NAS` here);
the command is wrapped in `timeout 5`, so a dead mount cannot freeze the disk
module.

The network module reads `/proc/net/dev` once per fast tick; `/proc/net/route`
and `/proc/net/ipv6_route` are read every 5 s, without spawning a process.

Swap devices are read from `/proc/swaps` every 5 s, and `mm_stat` every 10 s
per zram device, also without spawning a process.

The CPU tooltip reads `/proc/<pid>/stat` snapshots (no process) for
instantaneous deltas; the RAM tooltip launches a `ps` (~15 ms, wrapped in
`timeout 5`) when it opens and then every 5 s by default (2–10 s) while the
hover lasts, never in the background.

Temperature, disk, swap/ZRAM and alerts only run while at least one bar has
the corresponding module enabled; hiding them stops the scripts entirely.
Fan speeds travel with the temperature scan (`temperature.sh`), so they cost
no extra process. `alerts.sh` runs every 60 s (systemd system/user plus a
`ps` zombie scan) and only while Alerts is enabled.

PSI (`/proc/pressure/memory`, `/proc/pressure/io`, `/proc/pressure/cpu`),
`/proc/diskstats`, `/proc/net/wireless` and `/proc/uptime` are read every 5 s
without spawning a process. The SSID comes from the NetworkManager service
over D-Bus (no process, no poll); the signal level is read from
`/proc/net/wireless` every 5 s, and `wifi-freq.sh` asks `iw` for the
associated frequency every 30 s while the link is wireless only. The LAN and
public addresses are only fetched when the NET tooltip opens with extended
data: `ip -4` costs ~3 ms, and <https://api.ipify.org> is queried at most
every 5 minutes (one HTTPS request, nothing else is sent).

Full methodology, raw numbers and reproduction snippets:
[performance.md](performance.md).

## Checks

```bash
./check.sh
```

The script validates the manifest, checks shell script syntax and version
consistency, verifies the JSON/thermal output contracts, runs
`shellcheck --enable=all` on every script, and `qmllint` (Qt 6) with a proper
`qs.Commons`/`qs.Ui` import root.

## GPU

Sources used, in order:

1. `/sys/class/drm/*/device/gpu_busy_percent`;
2. `nvidia-smi`;
3. otherwise `GPU --%`.

### Apple Silicon / Asahi

On an Apple Silicon machine with the `asahi` driver (AGX), no GPU utilization
measurement is currently exposed by the system:

- no `gpu_busy_percent`;
- no `devfreq` or exposed GPU frequency;
- no `drm-engine-*` statistics in `/proc/<pid>/fdinfo`;
- no dedicated GPU power sensor;
- the driver exposes no utilization counter through debugfs/sysfs.

Existing tools do not cover this case: `btop` is built without GPU support,
`nvtop` only supports Apple on macOS (Metal), and `asitop`/`macmon` rely on
`powermetrics`, also macOS-only. YASSM therefore shows `GPU --%` on this
configuration rather than an invented value.

## Updating

The remote is:

```text
https://github.com/jotenakis2/yassm.git
```

`omarchy plugin update` can therefore be used. Otherwise, replace the files
manually and run `omarchy plugin validate` and
`omarchy-shell shell rescanPlugins` again.

No configuration file to migrate: settings live in `shell.json`.

## Uninstall

```bash
omarchy plugin disable io.github.jotenakis2.yassm
omarchy plugin remove io.github.jotenakis2.yassm
```

`disable` removes the widget from the bar while keeping the files. Because the
folder is a Git repository, `remove` deletes the folder: make sure to push the
repository or keep an archive first.

## License

MIT — see `LICENSE`.
