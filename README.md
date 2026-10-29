# YASSM — Yet Another Simple System Monitor

Version 1.29.34

**English** | [Français](README-fr.md)

A compact Omarchy bar widget: CPU, RAM, swap, load, GPU, disk, network,
temperature, battery, uptime and alerts, each with a detailed tooltip.

Repository: <https://github.com/jotenakis2/yassm>

## Screenshots

![YASSM in the Omarchy bar](docs/screenshots/bar.png)

| Tooltips | |
| --- | --- |
| ![CPU](docs/screenshots/tooltip-cpu.png) | ![RAM](docs/screenshots/tooltip-memory.png) |
| ![Network](docs/screenshots/tooltip-net.png) | ![Battery](docs/screenshots/tooltip-battery.png) |
| ![Disk](docs/screenshots/tooltip-disk.png) | ![Alerts](docs/screenshots/tooltip-alerts.png) |

<img src="docs/screenshots/settings.png" alt="Settings panel" width="380">

More in [`docs/screenshots`](docs/screenshots).

## Install

```bash
omarchy plugin add https://github.com/jotenakis2/yassm.git --enable
```

The widget is enabled with its default section. To move it:

```bash
omarchy plugin enable io.github.jotenakis2.yassm --section left
```

Use `left`, `center` or `right`.

## What it shows

| Module | Value |
| --- | --- |
| CPU | usage % |
| RAM | used % |
| Swap | used % (hidden without swap) |
| Load | run-queue load, as a CPU-normalised % (can exceed 100) |
| GPU | usage %; `--%` when the system exposes no counter (e.g. Apple Silicon) |
| Disk | root filesystem usage % |
| Network | ↓ and ↑ rates, or a crossed icon when offline |
| Temperature | hottest sensor °C |
| Battery | level %, with a state icon |
| Uptime | minutes below one hour, then `hMM` |
| Alerts | icon only, when an alert is active |

The order and visibility of every module are configurable.

## Clicks

| Left-click on | Opens |
| --- | --- |
| CPU, load, GPU, RAM, swap, temperature, uptime | `btop`, or `htop` if `btop` is missing |
| disk | the default file manager (home folder) |
| network | the Omarchy **Network Speed Test** |
| battery | the Omarchy **System** menu |
| alerts | the last hour of warnings/errors, then the failed systemd units |

Right-click opens **Settings**. A click outside the modules keeps the generic
target: `btop`, then `htop`; Settings when neither is installed.

## Tooltips

Hover a module for its details. **Extended data** in Settings adds the extra
rows marked below.

- **CPU**: per-core usage; top userland processes; PSI and per-core
  frequencies (extended);
- **RAM**: total, used, available; top userland processes; buffers, cache and
  PSI (extended);
- **Swap**: per-device usage, zram and zswap details (extended);
- **Disk**: usage per local filesystem and NFS/CIFS mounts (queried when the
  tooltip opens; a mount that does not answer within 2 s is omitted); I/O
  rates, PSI and per-process I/O (extended);
- **Network**: rates and session totals; a latency ping to omarchy.org
  (extended, at open then every Slow interval while the tooltip stays open);
  interface, LAN/public address, Wi-Fi SSID, frequency and signal (extended);
- **Temperature**: every sensor and fan speed, hottest first;
- **Battery**: state and time remaining; power, pack temperature, cycles and
  health (extended);
- **Uptime**: time since boot; installation age and date (extended);
- **Load**, **GPU**, **Alerts**: a short summary, or the alert list (failed
  units, zombies, disk/RAM).

Extended data adds per-core frequencies and PSI, disk and per-process I/O,
swap/zram/zswap details, Wi-Fi and LAN/WAN details, the NET latency ping, the
installation age, and battery power, temperature, cycles and health.

## Colors

When **Colors** is checked (the default), values change colour with the
current theme's green/orange/red; when it is unchecked, everything keeps the
normal bar colour. Thresholds apply to the rounded value shown in the bar:

| Module | Normal | Green | Orange | Red |
| --- | --- | --- | --- | --- |
| CPU, RAM, swap, GPU | < 10 % | 10–32 % | 33–65 % | ≥ 66 % |
| Disk | < 20 % | 20–32 % | 33–89 % | ≥ 90 % |
| Load | < 10 % | 10–49 % | 50–89 % | ≥ 90 % |
| Network | < 10 KiB/s | 10–499 KiB/s | 500–999 KiB/s | ≥ 1000 KiB/s |
| Battery | ≥ 50 % | 20–49 % | 11–19 % | ≤ 10 % |
| Temperature | < 40 °C | 40–49 °C | 50–59 °C | ≥ 60 °C |

Battery uses an inverted scale: the lower the value, the more alarming.
Thresholds are editable per family in Settings. With Colors on, the battery
icon turns green on mains power while the value keeps the normal bar colour.

## Alerts

The module stays hidden until something is wrong: a failed systemd unit, a
zombie older than 60 s, the root filesystem at 95 % or more, or RAM at 95 % or
more. Its icon shows the severity; the tooltip lists the cause.

## Settings

Right-click the widget. The panel has four sections:

- **Modules**: toggle a module, drag the handle to reorder;
- **Layout**: boxes, border width, corner radius, colors, extended data,
  spacing, processes shown;
- **Thresholds**: usage, disk, load, network, battery, temperature. Hidden
  while **Colors** is off;
- **Timers**: fast sampling (1–5 s) and slow sampling (5–30 s).

Preferences are stored in `~/.config/omarchy/shell.json`.

## Performance

YASSM is optimized to stay light: about **0.05 % of the machine** at the
default 1 s refresh, no resident process, and hidden modules stop sampling.
Measurements: [performance.md](performance.md).

## Requirements

Omarchy 4.x, `bash`, `awk`, coreutils, `findmnt`, `ps` and `systemd`. Optional:
`btop` or `htop` (left-click target), `curl` and `ip` (network addresses), `iw` (Wi-Fi
frequency), `ping` (NET latency), `nvidia-smi` (NVIDIA GPU), UPower and
NetworkManager (battery and SSID). A missing optional tool simply hides the corresponding field.

The widget needs a horizontal bar; it is hidden on vertical bars.

## Update

```bash
omarchy plugin update
```

Settings live in `shell.json`; there is no configuration file to migrate.

## Uninstall

```bash
omarchy plugin disable io.github.jotenakis2.yassm
omarchy plugin remove io.github.jotenakis2.yassm
```

`remove` deletes the folder: push the repository or keep an archive first.

## License

MIT — see [`LICENSE`](LICENSE).
