# Timers

Everything polled by YASSM follows **one of two cadences**, both user settings
(Settings → Timers):

| Cadence | Setting | Range | Default |
| --- | --- | --- | --- |
| **Fast** | Fast sampling | 1–5 s | 1 s |
| **Slow** | Slow sampling | 5–30 s | 10 s |

Only two things are fixed: **alerts** (60 s) and **battery cycles** (1 h).

## Fast

| Data | When |
| --- | --- |
| CPU, per-core %, load | always |
| RAM, swap % | always |
| Network rates, default route and interface | always |
| CPU frequency | CPU tooltip open |
| Disk I/O rates | DISK tooltip open |
| Swap devices, zram, zswap | SWAP tooltip open |
| Wi-Fi frequency and signal | NET tooltip open |

## Slow

| Data | When |
| --- | --- |
| Disk usage | always |
| Temperature | always |
| Uptime | always |
| GPU utilization | always |
| PSI `some`/`full` | RAM, CPU or DISK tooltip open |
| Processes (CPU/RAM) | their tooltip open |
| Disk I/O per process | DISK tooltip open |

## Fixed

| Data | Cadence | Source |
| --- | --- | --- |
| Alerts | 60 s | `alerts.sh` |
| Battery cycles | 3600 s | `cycle_count` |

## No timer

- Battery level and state, Wi-Fi SSID, connectivity: **events** over D-Bus
  (UPower, NetworkManager).
- Installation date, dependency check, GPU detection: **once**, when the
  shell starts (Quickshell process start or plugin reload).

## Notes

- On-demand rows only run while their tooltip is open: no process and no file
  read when nothing is hovered.
- Slow never goes below 5 s because disk and temperature each spawn a short
  script.
- LAN and WAN addresses are fetched when the NET tooltip opens (the WAN
  lookup is cached for 5 minutes).
