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
| Fréquence CPU | infobulle CPU ouverte |
| Débits disque | infobulle DISK ouverte |
| Fréquence et signal Wi-Fi | infobulle NET ouverte |

## Slow

| Donnée | Quand |
| --- | --- |
| Usage disque | toujours |
| Température | toujours |
| Uptime | toujours |
| Utilisation GPU | toujours |
| PSI `some`/`full` | infobulle RAM, CPU ou DISK ouverte |
| Périphériques de swap, zram, zswap | infobulle SWAP ouverte |
| Processus (CPU/RAM) | leur infobulle ouverte |
| E/S disque par processus (user) | infobulle DISK ouverte |

## Fixes

| Donnée | Cadence | Source |
| --- | --- | --- |
| Alertes | 60 s | `alerts.sh` |
| Cycles batterie | 3600 s | `cycle_count` |

## Aucun timer

- Niveau et état de la batterie, SSID Wi-Fi, connectivité : **événements**
  D-Bus (UPower, NetworkManager).
- Date d'installation, vérification des dépendances, détection GPU : **une
  fois**, au démarrage du shell (lancement du processus Quickshell ou
  rechargement du plugin).

## Remarques

- Les lignes « à l'ouverture » ne tournent que pendant l'infobulle concernée :
  aucun processus ni lecture de fichier quand rien n'est survolé.
- Slow ne descend pas sous 5 s car disque et température lancent chacun un
  script court.
- Les adresses LAN et publique sont récupérées à l'ouverture de l'infobulle
  NET (la recherche publique est mise en cache 5 minutes).
