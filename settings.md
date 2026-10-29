# Settings panel

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
- Box border (frame border width, 1–4 px; defaults to the theme border width)
- Box corner radius (0–12 px; default 4)
- Colors (colored thresholds and blue battery icon on mains)
- Extended data in tooltips (per-core CPU frequency, PSI, disk I/O, Wi-Fi, battery health)
- Between modules (gap between modules, 0–5 spaces; default 2)
- Between icon and value (gap between icon and value, 0–3 spaces; default 1)
- Processes shown (userland processes in tooltips, 1–20; default 10)

**Thresholds**

- Usage (%) — CPU, RAM, swap and GPU
- Disk (%)
- Load (%)
- Network (KiB/s)
- Battery (%) — inverted scale, hover its title for the explanation
- Temperature (°C)

Each family has three editable number fields (green, orange, red); type a
value or use the arrows. The order is always preserved, and the battery scale
is reversed: normal at or above Green, then green, orange and red as the
value drops.

**Timers**

- Fast sampling (fast metrics: CPU, RAM, swap, load, network, 1–5 s; default 1)
- Slow sampling (disk, temperature, uptime and GPU, 5–30 s; default 10)

Every cadence, including the fixed ones (alerts 60 s, battery cycles 1 h) and
the on-demand tooltip samplers, is listed in [timers.md](timers.md).

The **Between modules** slider sets the gap between modules from 0 to 5 spaces
(default 2). The **Between icon and value** slider sets the gap between each
module's icon and value from 0 to 3 spaces (default 1, i.e. 7.19 px). At 0, a
minimum gap of 2 px is kept.

The **Fast sampling** slider drives the fast loop (CPU, RAM, swap, load, network).
Network rates use the real elapsed time, so changing the interval does not
distort them. The CPU and RAM process lists follow the **Slow sampling**
interval while their tooltip is open. The **Processes shown** slider caps the userland
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
  "slowInterval": 10,
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

Threshold keys use `<family>Green`, `<family>Orange` and `<family>Red` for
`percent`, `disk`, `load`, `net` and `battery`, plus `tempWarm`, `tempHot` and
`tempCritical`.

All keys are optional; missing values use the defaults above. `moduleOrder`
is the list of module keys shown above (`net` covers both rate boxes); an
unknown key is dropped and a new module missing from the list is appended, so
an old `shell.json` never breaks the bar.

Version française : [settings-fr.md](settings-fr.md).
