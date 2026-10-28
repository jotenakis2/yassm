# Intervalles

Toutes les cadences utilisées par YASSM, par donnée. **Fast** et **Slow** sont
des réglages (Settings → Intervalles) ; les autres valeurs sont fixes.

| Donnée | Cadence | Type | Source |
| --- | --- | --- | --- |
| CPU, % par cœur, load | **Fast** (Échantillonnage rapide, 1–5 s) | fond | `/proc/stat`, `/proc/loadavg` |
| RAM, swap % | **Fast** | fond | `/proc/meminfo` |
| Débits réseau | **Fast** | fond | `/proc/net/dev` |
| Route par défaut, interface, état en ligne | **Fast** | fond | `/proc/net/route`, `/proc/net/ipv6_route` |
| Utilisation GPU | 10 s | fixe | sysfs ou `nvidia-smi` |
| Usage disque | **Slow** (5–30 s) | fond | `findmnt` |
| Température (barre) | **Slow** | fond | `temperature.sh` |
| Uptime | **Slow** | fond | `/proc/uptime` |
| Alertes (unités systemd, zombies) | **60 s** | fixe | `alerts.sh` |
| Cycles batterie | **3600 s** | fixe | `cycle_count` |
| PSI `some`/`full` | 5 s pendant qu'un tooltip est ouvert | à la demande | `/proc/pressure/*` |
| Débits disque | 5 s pendant que DISK est ouvert | à la demande | `/proc/diskstats` |
| Périphériques de swap, zswap | 5 s pendant que SWAP est ouvert | à la demande | `/proc/swaps`, sysfs zswap |
| Statistiques zram | 5 s pendant que SWAP est ouvert | à la demande | `mm_stat` |
| Fréquence Wi-Fi | 10 s pendant que NET est ouvert | à la demande | `wifi-freq.sh` |
| Signal Wi-Fi | 5 s pendant que NET est ouvert | à la demande | `/proc/net/wireless` |
| SSID Wi-Fi | événements | événement | NetworkManager |
| Fréquence CPU | 2 × Fast pendant que CPU est ouvert | à la demande | `cpu-freq.sh` |
| Processus (CPU/RAM) | **Slow** pendant l'ouverture de leur tooltip | à la demande | `proc-snapshot.sh`, `ps` |
| E/S disque par processus | **Slow** pendant que DISK est ouvert (+ 1 s de préchauffage) | à la demande | `disk-io.sh` |
| Niveau et état batterie | événements | événement | UPower |
| Date d'installation | une fois | une fois | `install-date.sh` |
| Dépendances, détection GPU | une fois au démarrage | une fois | `deps.sh`, `detect-gpu.sh` |

## Remarques

- Les échantillonneurs **à la demande** s'arrêtent dès que leur tooltip se
  ferme : aucun processus ni lecture de fichier tant que rien n'est survolé.
- **Slow** règle les trois valeurs de barre qui changent lentement (disque,
  température, uptime) et les listes de processus pendant l'ouverture de leur
  tooltip. Il ne descend pas sous 5 s car disque et température
  lancent chacun un script court.
- **Fixes** : les alertes restent à 60 s (systemd + zombies, peu coûteux et
  stable), les cycles batterie à 1 h (ils ne changent qu'à un cycle complet).
- Le niveau de batterie, l'état de charge et le SSID Wi-Fi sont événementiels
  via D-Bus : aucun polling.
