# Timers

Every cadence used by YASSM, by data. **Fast** and **Slow** are user settings
(Settings → Timers); the other values are fixed on purpose.

| Data | Cadence | Kind | Source |
| --- | --- | --- | --- |
| CPU, per-core %, load | **Fast sampling** (1–5 s) | background | `/proc/stat`, `/proc/loadavg` |
| RAM, swap % | **Fast** | background | `/proc/meminfo` |
| Network rates | **Fast** | background | `/proc/net/dev` |
| Default route, interface, online state | **Fast** | background | `/proc/net/route`, `/proc/net/ipv6_route` |
| Disk usage | **Slow** (5–30 s) | background | `findmnt` |
| Temperature (bar) | **Slow** | background | `temperature.sh` |
| Uptime | **Slow** | background | `/proc/uptime` |
| Alerts (systemd units, zombies) | **60 s** | fixed | `alerts.sh` |
| Battery cycles | **3600 s** | fixed | `cycle_count` |
| PSI `some`/`full` | 5 s while a tooltip is open | on demand | `/proc/pressure/*` |
| Disk I/O rates | 5 s while DISK is open | on demand | `/proc/diskstats` |
| Swap devices, zswap | 5 s while SWAP is open | on demand | `/proc/swaps`, zswap sysfs |
| zram stats | 5 s while SWAP is open | on demand | `mm_stat` |
| Wi-Fi frequency | 10 s while NET is open | on demand | `wifi-freq.sh` |
| Wi-Fi signal | 5 s while NET is open | on demand | `/proc/net/wireless` |
| Wi-Fi SSID | events | event | NetworkManager |
| CPU frequency | 2 × Fast while CPU is open | on demand | `cpu-freq.sh` |
| Processes (CPU/RAM) | Processes (2–10 s) while open | on demand | `proc-snapshot.sh`, `ps` |
| Disk I/O per process | Processes while DISK is open (+ 1 s warm-up) | on demand | `disk-io.sh` |
| Battery level and state | events | event | UPower |
| Installation date | once | once | `install-date.sh` |
| Dependencies, GPU detection | once at startup | once | `deps.sh`, `detect-gpu.sh` |

## Notes

- **On demand** samplers stop as soon as their tooltip closes: no process and
  no file read while nothing is hovered.
- **Slow** drives the three bar values that change slowly (disk, temperature,
  uptime). It never goes below 5 s because disk and temperature each spawn a
  short script.
- **Fixed**: alerts stay at 60 s (systemd + zombies, cheap and stable), battery
  cycles at 1 h (they only change on a full cycle).
- Battery level, charge state and the Wi-Fi SSID are event-driven over D-Bus:
  no polling at all.
