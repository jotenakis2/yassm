# YASSM — Yet Another Simple System Monitor

Version 1.9.14

**English** | [Français](README-fr.md)

Omarchy bar widget showing CPU, RAM, swap, system load, temperature, GPU and
root partition usage.

Repository: <https://github.com/jotenakis2/yassm>

## Modules

| Module | Source | Refresh |
| --- | --- | --- |
| CPU | `/proc/stat` | 1 s |
| RAM | `/proc/meminfo` (`MemAvailable`) | 1 s |
| Swap | `/proc/meminfo` (bar), `/proc/swaps` + zram `mm_stat` (tooltip) | 1 s / 10 s |
| Load average | `/proc/loadavg`, normalized by CPU count, not capped at 100 % | 1 s |
| GPU | `nvidia-smi` or sysfs `gpu_busy_percent` | 10 s |
| Disk | `findmnt` (root for the bar, all filesystems in the tooltip) | 15 s |
| Network | `/proc/net/dev` (default route interface) | 1 s |
| Battery | UPower (D-Bus, event-driven) | immediate on event (~30 s otherwise) |
| Temperature | all normal temperatures, sorted | 10 s |

Swap is hidden when the machine has no active swap. The GPU shows `--%` when
no reliable source is available. The network is displayed in two separate
boxes, ↓ and ↑.

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
- `bash`, `find`, `sort` and `findmnt` (util-linux).
- A Nerd Font for the icons.
- Optional: `nvidia-smi` for NVIDIA GPUs.

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

- CPU
- Load
- GPU
- Memory
- Swap
- Disk (`/`)
- Network
- Temperature
- Battery
- Bar colors (colored thresholds and blue battery on mains)
- Spacing (gap between modules, 0–5 spaces; default 2)

The **Spacing** slider sets the gap between modules from 0 to 5 spaces
(default 2). It also applies between the ↓ and ↑ rates of the network module.
At 0, a minimum gap of 2 px is kept to avoid any overlap.

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
  "spacing": 2
}
```

All keys are optional; missing values default to `true`.

## Tooltips

Hovering a module shows a contextual tooltip:

- **Load**: raw, non-normalized 1, 5 and 15 minute load, in aligned columns;
- **RAM**: the tooltip shows `Total`, `Used`, `Available` and `Buffer/cache`
  (`Buffers` + `Cached` + `SReclaimable`, like `free`). A `kernel` line shows
  kernel memory (Slab + stacks + page tables + vmalloc + percpu); vmalloc and
  percpu may slightly overlap. On hover, a single `ps` sample adds the top 10
  **userland** processes by RSS, grouped by name; kernel threads are excluded;
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
  session total (deltas since the shell started, reset on restart). Both rates
  are colored independently. The driver's absolute counter is not used because
  it can be bogus;
- **Temperature**: all normal temperatures found, sorted from highest to
  lowest, with the sensor name in parentheses; the bar shows the highest one.
  The icon follows the level: snowflake below 40 °C, thermometer from 40 to
  49 °C, heat from 50 to 59 °C, alert from 60 °C;
- **Battery**: percentage, state, time remaining or time to full, and
  instantaneous power when UPower provides it, with direction (`draw` while
  discharging, `charge` while charging);
- **CPU**: current percentage. A `kernel` line shows kernel CPU (`system` +
  `irq` + `softirq`), on the same scale as the processes. On hover, a single
  `ps` sample adds the top 10 **userland** processes by CPU (average since
  process start, scaled to total CPU capacity like the main value), grouped by
  name; kernel threads are excluded;
- **GPU**: current percentage.

Network, swap, disk and temperature tooltips launch no process. CPU and RAM
tooltips launch a single `ps` when they open and do not refresh it while the
hover lasts.

## Bar colors

On the bar only, not in tooltips. Thresholds apply to the rounded displayed
value:

| Module | Normal | Green | Orange | Red |
| --- | --- | --- | --- | --- |
| CPU, RAM, Swap, Disk, GPU | < 10 % | 10–32 % | 33–65 % | ≥ 66 % |
| Load | ≤ 10 % | 11–50 % | 51–90 % | > 90 % |
| Network | < 10 KiB/s | 10–499 KiB/s | 500–1000 KiB/s | > 1000 KiB/s |
| Battery | ≥ 50 % | 20–49 % | 10–19 % | < 10 % |
| Temperatures | < 40 °C | 40–49 °C | 50–59 °C | ≥ 60 °C |

Load is not capped: it can exceed 100 % when the run queue is longer than the
CPU count. Battery uses inverted logic: the lower the value, the more alarming
the color. Network download and upload rates are colored independently.

The green/orange/red colors come from the current Omarchy theme's
`colors.toml`. Icons keep the normal bar color, except for the battery: as
soon as the machine is on mains power (charging or held at a charge threshold),
its value and icon turn theme blue. On battery, the value follows the
thresholds above.

The **Bar colors** toggle disables all these colors: values and the blue
battery tint return to the normal bar color. It maps to `showColors` in
`shell.json` (enabled by default).

## Battery icon

The icon follows the level in 10 % steps (empty battery below 10 %) and the
power state:

- **on battery**: battery alone, filled according to the level;
- **charging**: battery with a bolt, value and icon blue;
- **plugged but not charging** (full or charge threshold reached): battery
  followed by a plug, value and icon blue.

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
| `findmnt` | 2.0 ms | 4×/min | 8 ms |
| Battery (UPower) | 0 | event-driven | 0 |

**Total overhead ≈ 0.16 % of one core, ~14 MiB RSS, no resident process.**
YASSM is therefore very performant: no battery polling (UPower is
event-driven), a single sampling series shared by every bar, and tooltips
launch no process.

`findmnt` may wait ~100 ms on I/O for a network mount (`/media/NAS` here);
that wait does not consume CPU.

The network module adds two file reads per second (`/proc/net/dev` and
`/proc/net/route`, ~8 µs), inside the existing timer and without spawning a
process.

The swap detail adds one `/proc/swaps` read per second and one `mm_stat` read
per zram device every 10 s, also without spawning a process.

The CPU and RAM tooltips launch a single `ps` (~15 ms) when they open, never in
the background.

## Checks

```bash
./check.sh
```

The script validates the manifest, checks shell script syntax, runs
`shellcheck` when available and `qmllint` (Qt 6) on the QML files.

## GPU

Sources used:

1. `nvidia-smi`;
2. `/sys/class/drm/*/device/gpu_busy_percent`;
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
