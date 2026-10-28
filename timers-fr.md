# Intervalles

Tout ce que YASSM échantillonne suit **l'une de deux cadences**, toutes deux
réglables (Settings → Intervalles) :

| Cadence | Réglage | Plage | Défaut |
| --- | --- | --- | --- |
| **Fast** | Échantillonnage rapide | 1–5 s | 1 s |
| **Slow** | Échantillonnage lent | 5–30 s | 10 s |

Seules deux choses sont fixes : les **alertes** (60 s) et les **cycles
batterie** (1 h).

## Fast

| Donnée | Quand |
| --- | --- |
| CPU, % par cœur, load | toujours |
| RAM, swap % | toujours |
| Débits réseau, route par défaut et interface | toujours |
| Fréquence CPU | tooltip CPU ouvert |
| PSI `some`/`full` | tooltip RAM, CPU ou DISK ouvert |
| Débits disque | tooltip DISK ouvert |
| Périphériques de swap, zram, zswap | tooltip SWAP ouvert |
| Fréquence et signal Wi-Fi | tooltip NET ouvert |

## Slow

| Donnée | Quand |
| --- | --- |
| Usage disque | toujours |
| Température | toujours |
| Uptime | toujours |
| Utilisation GPU | toujours (si le module GPU est activé) |
| Processus (CPU/RAM) | leur tooltip ouvert |
| E/S disque par processus | tooltip DISK ouvert |

## Fixes

| Donnée | Cadence | Source |
| --- | --- | --- |
| Alertes : unités systemd en échec, zombies | 60 s | `alerts.sh` |
| Cycles batterie | 3600 s | `cycle_count` |

## Aucun timer

- Niveau et état de la batterie, SSID Wi-Fi, connectivité : **événements**
  D-Bus (UPower, NetworkManager).
- Date d'installation, vérification des dépendances, détection GPU : **une
  fois** au démarrage.

## Remarques

- Les lignes « à l'ouverture » ne tournent que pendant le tooltip concerné :
  aucun processus ni lecture de fichier quand rien n'est survolé.
- Slow ne descend pas sous 5 s car disque et température lancent chacun un
  script court.
