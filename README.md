# YASSM — Yet Another Simple System Monitor

Version 1.10.27

**English** | [Français](README-fr.md)

Omarchy bar widget showing CPU, RAM, swap, system load, network, temperature,
GPU and root partition usage.

Repository: <https://github.com/jotenakis2/yassm>

## Modules

| Module | Source | Refresh |
| --- | --- | --- |
| CPU | `/proc/stat` | 1 s |
| RAM | `/proc/meminfo` (`MemAvailable`) | 1 s |
| Swap | `/proc/meminfo` (bar), `/proc/swaps` (5 s) + zram `mm_stat` (tooltip, 10 s) | 1 s |
| Load average | `/proc/loadavg`, normalized by CPU count, not capped at 100 % | 1 s |
| GPU | sysfs `gpu_busy_percent`, or `nvidia-smi` | 10 s |
| Disk | `findmnt` (root for the bar, all filesystems in the tooltip) | 10 s |
| Network | `/proc/net/dev` (default route, IPv4 then IPv6) | 1 s |
| Battery | UPower (D-Bus, event-driven) | immediate on event (~30 s otherwise) |
| Temperature | all normal temperatures, sorted | 10 s |

Swap is hidden when the machine has no active swap. The GPU shows `--%` when
no reliable source is available. The network is displayed in two separate
boxes, ↓ and ↑. CPU, RAM, swap, load and network share one fast loop, 1 s by
default and configurable from 1 to 5 s in Settings.

## Architecture

- `lib/SystemMetrics.qml` is a shared singleton: a single `/proc` sampler and a
  single `findmnt` for every bar instance, including multi-monitor setups.
  Battery data comes directly from UPower (event-driven).
- `SettingsPanel.qml` is loaded on demand on first click, then kept for
  subsequent openings. Its controls are Omarchy `Toggle`/`ToggleSwitch`,
  using the current theme's fonts, colors and spacing.
- GPU support remains handled by the widget, consistent with the current
  limitation of Asahi support.

## Requirements

- Omarchy 4.x with its Quickshell shell.
- `bash`, `findmnt` (util-linux), `ps` (procps-ng) and `timeout` (coreutils).
- A Nerd Font for the icons.
- Optional: `nvidia-smi` for NVIDIA GPUs.

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

Clicking the widget opens a panel to enable or disable:

**Modules**

- CPU
- Load
- GPU
- Memory
- Swap
- Disk (`/`)
- Network
- Temperature
- Battery

**Layout**

- Boxes (module frames)
- Colors (colored thresholds and blue battery icon on mains)
- Between modules (gap between modules, 0–5 spaces; default 2)
- Between icon and value (gap between icon and value, 0–3 spaces; default 1)

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
restart their `ps` while open; it goes down to 2 s. Hovering any slider row
shows a tooltip with the same explanation. The panel scrolls automatically if
the screen is too short.

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
  "showColors": true,
  "showBoxes": true,
  "spacing": 2,
  "iconGap": 1,
  "refreshInterval": 1,
  "processInterval": 5
}
```

All keys are optional; missing values use the defaults above.

## Tooltips

Hovering a module shows a contextual tooltip:

- **Load**: raw, non-normalized 1, 5 and 15 minute load, in aligned columns.
  The icon tilts with the load: needle low up to 50 %, medium from 51 to 90 %,
  high above that;
- **RAM**: the tooltip opens with a centered `data` heading, then shows
  `Total`, `Used`, `Available` and `Buffer/cache` (`Buffers` + `Cached` +
  `SReclaimable`, like `free`). A centered `proc` heading introduces the
  `kernel` line (Slab − SReclaimable + stacks + page tables + vmalloc +
  percpu; SReclaimable is already in Buffer/cache, and vmalloc and percpu may
  slightly overlap) and the top 10 **userland** processes by RSS,
  grouped by name; the list refreshes every 5 s by default (2–10 s) while the
  tooltip stays open;
  kernel threads are excluded;
- **Swap**: each swap device is listed with used / total and its percentage,
  including zram. A `ZRAM` section shows, for each zram device, the compressed
  size, original size, ratio and RAM used. When ZSWAP is in use, a `ZSWAP`
  block shows the compressed size, the original size and the compression
  ratio;
- **Disk**: one line per detected real filesystem, in GiB, with the
  percentage. Pseudo filesystems (`proc`, `sysfs`, `tmpfs`, `cgroup`, etc.)
  are ignored, along with ephemeral mounts under `/tmp` (AppImage, FUSE) and
  `/run/user`. Mount points that share the same device/source are
  deduplicated: on a btrfs root with subvolumes, `/home` and `/var/log`
  therefore do not appear separately from `/`;
- **Network**: active interface, download (↓) and upload (↑) rates, plus the
  session total (deltas since the shell started, reset on restart and kept
  across interface changes). Both rates are colored independently. The
  driver's absolute counter is not used because it can be bogus;
- **Temperature**: all normal temperatures found, sorted from highest to
  lowest, with the sensor name in parentheses; the bar shows the highest one.
  The icon follows the level (thresholds on the rounded displayed value):
  snowflake below 40 °C, thermometer from 40 to 49 °C, heat from 50 to 59 °C,
  alert from 60 °C;
- **Battery**: percentage, state, time remaining or time to full, and
  instantaneous power when UPower provides it, with direction (`draw` while
  discharging, `charge` while charging);
- **CPU**: current percentage. The tooltip opens with a centered `cores`
  heading, then per-core percentages in two columns (split in half; three or
  more columns past 20 cores, at most 10 rows tall). A centered `proc`
  heading then introduces kernel CPU (`system` + `irq` + `softirq`), on the
  same scale as the processes, followed by the top 10 **userland** processes by
  CPU (average since process start, scaled to total CPU capacity like the main
  value), grouped by name; the list refreshes every 5 s by default (2–10 s)
  while the tooltip stays open; kernel threads are excluded;
- **GPU**: current percentage.

Tooltip titles (`CPU`, `RAM`, `NET`, etc.) and section headings (`cores`,
`data`, `proc`, `ZRAM`, `ZSWAP`) are **bold** and use the tooltip text color;
the body uses the theme `muted` color. The `kernel` line in the CPU and RAM
tooltips is bold too, but keeps the body color. Network, swap, disk and
temperature tooltips launch no process. CPU and RAM tooltips launch a `ps` when
they open and then every 5 s by default (2–10 s) while the hover lasts.

## Bar colors

On the bar only, not in tooltips. Thresholds apply to the rounded displayed
value:

| Module | Normal | Green | Orange | Red |
| --- | --- | --- | --- | --- |
| CPU, RAM, Swap, Disk, GPU | < 10 % | 10–32 % | 33–65 % | ≥ 66 % |
| Load | ≤ 10 % | 11–50 % | 51–90 % | > 90 % |
| Network | < 10 KiB/s | 10–499 KiB/s | 500–1000 KiB/s | > 1000 KiB/s |
| Battery | ≥ 50 % | 20–49 % | 11–19 % | ≤ 10 % |
| Temperatures | < 40 °C | 40–49 °C | 50–59 °C | ≥ 60 °C |

Load is not capped: it can exceed 100 % when the run queue is longer than the
CPU count. Battery uses inverted logic: the lower the value, the more alarming
the color. Network download and upload rates are colored independently.

The green/orange/red colors come from the current Omarchy theme's
`colors.toml`. Icons keep the normal bar color, except for the battery icon:
as soon as the machine is on mains power (charging or held at a charge
threshold), the icon turns theme blue while the value keeps the normal bar
color. On battery, the value follows the thresholds above.

The **Colors** toggle disables all these colors: values and the blue
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
30 s, so the percentage may change at that rate.

## Performance

Measured over two 5-minute windows, machine idle, screensaver and locking
disabled (Apple M2 Pro, Omarchy 4.0.3, Quickshell 0.3.2):

| Scenario | `quickshell` CPU (1 core) | Average RSS | Wakeups / 5 min |
| --- | --- | --- | --- |
| Without YASSM | 2.413 % | 736 MiB | 27,385 |
| With YASSM | 2.447 % | 750 MiB | 29,575 |
| **Overhead** | **+0.034 points** | **+14 MiB** | **+2,190** |

Plus the short-lived scripts (CPU measured over 50 runs):

| Script | CPU / run | Frequency | CPU / minute |
| --- | --- | --- | --- |
| `temperature.sh` | 11.0 ms | 6×/min | 66 ms |
| `findmnt` | 2.0 ms | 6×/min | 12 ms |
| Battery (UPower) | 0 | event-driven | 0 |

**Total overhead ≈ 0.16 % of one core, ~14 MiB RSS, no resident process.**
YASSM is therefore very performant: no battery polling (UPower is
event-driven), a single sampling series shared by every bar, and most tooltips
launch no process.

`findmnt` may wait ~100 ms on I/O for a network mount (`/media/NAS` here);
the command is wrapped in `timeout 5`, so a dead mount cannot freeze the disk
module.

The network module reads `/proc/net/dev` once per fast tick; `/proc/net/route`
and `/proc/net/ipv6_route` are read every 5 s, without spawning a process.

Swap devices are read from `/proc/swaps` every 5 s, and `mm_stat` every 10 s
per zram device, also without spawning a process.

The CPU and RAM tooltips launch a `ps` (~15 ms, wrapped in `timeout 5`) when
they open and then every 5 s by default (2–10 s) while the hover lasts, never
in the background.

## Checks

```bash
./check.sh
```

The script validates the manifest, checks shell script syntax and version
consistency, verifies the JSON/thermal output contracts, runs `shellcheck`
when available and `qmllint` (Qt 6) with a proper `qs.Commons`/`qs.Ui` import
root.

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
