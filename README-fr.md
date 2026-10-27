# YASSM — Yet Another Simple System Monitor

Version 1.17.0

[English](README.md) | **Français**

Widget de barre Omarchy affichant l'uptime, CPU, RAM, swap, charge système,
réseau, température, GPU, batterie, alertes et usage de la partition racine.

Dépôt : <https://github.com/jotenakis2/yassm>

## Modules

| Module | Source | Rafraîchissement |
| --- | --- | --- |
| CPU | `/proc/stat` | 1 s |
| RAM | `/proc/meminfo` (`MemAvailable`) | 1 s |
| Swap | `/proc/meminfo` (barre), `/proc/swaps` (5 s) + zram `mm_stat` (tooltip, 10 s) | 1 s |
| Load average | `/proc/loadavg`, normalisée par le nombre de CPU, sans plafond à 100 % | 1 s |
| GPU | `gpu_busy_percent` sysfs, ou `nvidia-smi` | 10 s |
| Disque | `findmnt` (racine pour la barre, FS locaux dans le tooltip) | 10 s |
| Réseau | `/proc/net/dev` (route par défaut, IPv4 puis IPv6) | 1 s |
| Batterie | UPower (D-Bus, événementiel) | immédiat sur événement (~30 s sinon) |
| Alertes | unités systemd en échec + zombies de plus de 60 s | 60 s |
| Uptime | `/proc/uptime`, affiché en minutes ou `hMM` | 5 s |
| Température | toutes les températures normales, triées | 10 s |

Le swap est masqué lorsque la machine n'a pas de swap actif. Le GPU affiche
`--%` lorsqu'aucune source fiable n'est disponible. Le réseau est affiché dans
deux boîtes distinctes, ↓ et ↑. CPU, RAM, swap, load et réseau partagent une
seule boucle rapide, 1 s par défaut et réglable de 1 à 5 s dans Settings.

## Architecture

- `lib/SystemMetrics.qml` est un singleton partagé : un seul échantillonneur
  `/proc` et un seul `findmnt` pour toutes les instances de barre, y compris
  sur plusieurs écrans. La batterie vient directement d'UPower (événementiel).
- `SettingsPanel.qml` est chargé à la demande à la première ouverture, puis conservé
  pour les ouvertures suivantes. Ses contrôles sont des `Toggle`/`ToggleSwitch`
  Omarchy, avec les polices, couleurs et espacements du thème courant.
- Le GPU reste géré par le widget, conformément à la limite actuelle du
  support Asahi.

## Prérequis

- Omarchy 4.x avec son shell Quickshell.
- `bash`, `findmnt` (util-linux), `ps` (procps-ng) et `timeout` (coreutils).
- Une police Nerd Font pour les icônes.
- Optionnel : `nvidia-smi` pour les GPU NVIDIA.
- Optionnel : `btop` pour le lanceur au clic gauche.
- Optionnel : `systemctl` (systemd) pour le module Alerts.

Le widget est conçu pour une barre horizontale (haut ou bas). Il est masqué
sur une barre verticale, où un emplacement de `barSize` de large ne peut pas
contenir la rangée de modules.

## Installation

```bash
unzip yassm.zip -d "$HOME/.config/omarchy/plugins/"
omarchy plugin validate "$HOME/.config/omarchy/plugins/io.github.jotenakis2.yassm"
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.jotenakis2.yassm --section left
```

La dernière commande place le widget dans la section `left` de la barre ;
adaptez `--section` (`left`, `center`, `right`) selon votre préférence.

## Panneau de configuration

**Clic droit** sur le widget pour ouvrir le panneau ; **clic gauche** lance ou
focus `btop` s'il est installé (Omarchy le rend flottant en 875×600). Si `btop`
n'est pas installé, le clic gauche ouvre le panneau à la place.

Le panneau permet d'activer ou de désactiver :

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

- Boxes (encadrement des modules)
- Colors (seuils colorés et icône batterie bleue sur secteur)
- Extended data in tooltip (fréquence par cœur, PSI, I/O disque, Wi-Fi, santé batterie)
- Between modules (espacement entre modules, 0–5 espaces ; 2 par défaut)
- Between icon and value (espace icône ↔ valeur, 0–3 espaces ; 1 par défaut)
- Processes shown (processus userland affichés, 1–20 ; 10 par défaut)

**Timers**

- Refresh (intervalle d'échantillonnage des métriques, 1–5 s ; 1 par défaut)
- Processes (rafraîchissement des processus du tooltip, 2–10 s ; 5 par défaut)

Le curseur **Between modules** règle l'espacement entre les modules de 0 à 5
espaces (2 par défaut). Le curseur **Between icon and value** règle l'espace
entre l'icône et la valeur de chaque module de 0 à 3 espaces (1 par défaut,
soit 7,19 px). À 0, un écart minimal de 2 px est conservé.

Le curseur **Refresh** pilote la boucle rapide (CPU, RAM, swap, load, réseau).
Les débits réseau utilisent le temps réel écoulé, donc changer l'intervalle ne
les fausse pas. Le curseur **Processes** règle la fréquence de rafraîchissement
des tooltips CPU et RAM ; il descend jusqu'à 2 s. Le curseur **Processes shown**
plafonne la liste userland à 1–20 lignes (10 par défaut) ; la ligne `kernel`
est toujours en plus. La liste CPU est instantanée (deltas `/proc/<pid>/stat`),
la RAM utilise le RSS de `ps`. **Extended data in tooltip** ajoute la fréquence
CPU, la pression PSI, les I/O disque, le signal Wi-Fi et la santé de la
batterie à leurs tooltips ; l'option est active par défaut. Survoler
n'importe quelle ligne de curseur affiche une infobulle avec ces explications.
Le panneau défile automatiquement si l'écran est trop court ; Échap le ferme.

Les préférences sont enregistrées dans `~/.config/omarchy/shell.json`, dans
l'entrée de barre du widget. Il n'y a pas de fichier de configuration séparé.

Exemple d'entrée :

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
  "maxProcesses": 10
}
```

Toutes les clés sont optionnelles ; les valeurs absentes utilisent les défauts
ci-dessus.

## Tooltips

Le survol d'un module affiche une infobulle contextuelle :

- **Load** : charge réelle non normalisée sur 1, 5 et 15 minutes, en colonnes
  alignées. L'icône change d'inclinaison selon la charge : aiguille basse
  jusqu'à 50 %, médium de 51 à 90 %, haute au-delà ;
- **RAM** : le tooltip s'ouvre sur un titre `data` centré, puis affiche `Total`,
  `Used` et `Available`. Un titre `proc` centré introduit le top des processus
  **userland** par RSS (jusqu'à la valeur **Processes shown**, 10 par défaut),
  regroupés par nom ; la liste est rafraîchie toutes les 5 s par défaut
  (2–10 s) tant que le tooltip reste ouvert ; les threads noyau sont exclus.
  Extended data ajoute `Shared` (`Shmem` : tmpfs et mappings partagés, déjà
  comptés dans `Cached`), `Buffer/cache` (`Buffers` + `Cached` +
  `SReclaimable`, comme `free`), la ligne `kernel` (Slab − SReclaimable +
  piles + tables de pages + vmalloc + percpu ; SReclaimable est déjà dans
  Buffer/cache, et `vmalloc` et `percpu` peuvent se recouvrir légèrement) et
  une section `pressure` avec une ligne par fenêtre (`10s`, `60s`, `300s`) ;
- **Swap** : utilisé / total et le pourcentage. Extended data liste
  chaque périphérique de swap (zram compris) avec son propre utilisé / total
  et son pourcentage sous un titre `devices`, puis une section `zram` (taille
  compressée, taille originale, ratio et RAM utilisée par périphérique) et un
  bloc `zswap` (taille compressée, taille originale, ratio) dès que zswap est
  activé, même si son pool est vide ;
- **Disk** : une section `usage` avec une ligne par système de fichiers
  **local** détecté, en GiB, avec le pourcentage. Les pseudo-filesystems (`proc`, `sysfs`, `tmpfs`, `cgroup`,
  etc.) sont ignorés, ainsi que les montages éphémères sous `/tmp` (AppImage,
  FUSE) et `/run/user`. Les systèmes de fichiers réseau (NFS, CIFS, SSHFS…)
  sont ignorés : interroger leur usage peut bloquer plusieurs secondes quand
  le serveur est injoignable. Les points de montage qui partagent le même
  device/source sont dédupliqués : sur un root btrfs avec subvolumes, `/home`
  et `/var/log` n'apparaissent donc pas séparément de `/`. Extended data
  ajoute une section `io` (débits lecture/écriture) et une section `pressure`
  (`10s`, `60s`, `300s`) ;
- **Réseau** : une section `io` avec le débit descendant (↓), montant (↑) et
  le total de la session (deltas depuis le démarrage du shell, remis à zéro au
  redémarrage et conservés lors d'un changement d'interface), puis une section
  `iface` avec le nom de l'interface. Les deux débits sont colorés
  indépendamment. Le compteur absolu du pilote n'est pas utilisé, car il peut
  être aberrant. Sans route par défaut (uniquement `lo`), une icône réseau
  barrée rouge et `--` remplacent les deux débits. Extended data complète la
  ligne `iface` avec l'adresse LAN (`ip -4`) et l'adresse publique
  (`wlan0 · 192.168.50.148 · 90.29.68.78`), puis ajoute le SSID (via
  NetworkManager), la fréquence associée (`iw`, par ex. `5500 MHz`) et le
  niveau du signal (via `/proc/net/wireless`) quand la liaison est sans fil :
  `MaisonDuRuet · 5500 MHz · -67 dBm` ;
- **Temperature** : le tooltip s'intitule `SENSORS`. Une section
  `temperatures` liste toutes les mesures normales, triées de la plus élevée à
  la plus basse, avec le nom du capteur entre parenthèses ; la barre affiche
  la plus élevée. Les capteurs étiquetés gardent leur libellé, les capteurs
  hwmon sans libellé affichent seulement le nom du périphérique
  (`macsmc_battery`, `tas2764`), et les mesures qui partagent un nom sont
  fusionnées en gardant la plus chaude. L'icône de la barre suit le niveau
  (seuils sur la valeur arrondie affichée) : flocon sous 40 °C, thermomètre de
  40 à 49 °C, chaleur de 50 à 59 °C, alerte à partir de 60 °C. Une section
  `fans` liste chaque ventilateur hwmon avec sa vitesse en rpm
  (`Fan 1  0 rpm`), y compris les ventilateurs à l'arrêt à 0 ;
- **Battery** : pourcentage, état, temps restant ou temps de charge.
  Extended data ajoute la puissance instantanée quand UPower la fournit, avec
  sa direction sous forme de flèche (↓ en décharge, ↑ en charge), ainsi que la
  santé de la batterie et le nombre de cycles ;
- **CPU** : pourcentage courant. Le tooltip s'ouvre sur un titre `cores`
  centré, puis le pourcentage par cœur sur deux colonnes (réparties par
  moitié ; trois colonnes ou plus au-delà de 20 cœurs, 10 lignes maximum). Un
  titre `proc` centré introduit le top des processus **userland** par CPU
  (deltas instantanés depuis `/proc/<pid>/stat`, ramenés sur la capacité
  totale des CPU comme la valeur principale ; jusqu'à **Processes shown**, 10
  par défaut), regroupés par nom ; si moins de processus sont actifs, des
  lignes inactives à 0,0 % complètent la liste ; la liste est rafraîchie
  toutes les 5 s par défaut (2–10 s) tant que le tooltip reste ouvert ; les
  threads noyau sont exclus. Extended data ajoute le CPU noyau (`system` +
  `irq` + `softirq`, sur la même échelle que les processus) et la fréquence de
  chaque cœur entre parenthèses, alignée par colonne ;
- **Uptime** : minutes sous une heure (`42m`), puis `3h42` ; le tooltip
  affiche la même durée avec un espace (`3h 42m`) ;
- **GPU** : pourcentage courant.

Les titres des tooltips (`CPU`, `RAM`, `NET`, `SENSORS`, etc.) et les intitulés
de section (`cores`, `data`, `pressure`, `proc`, `usage`, `io`, `devices`,
`temperatures`, `fans`, `zram`, `zswap`) sont en **gras** et dans la couleur de
texte du tooltip ; le corps utilise la couleur `muted` du thème. La ligne
`kernel` des tooltips CPU et RAM (extended data uniquement) est aussi en gras,
mais conserve la couleur du corps. Les valeurs sont formatées à la demande, uniquement pendant le survol.

## Couleurs de la barre

Uniquement sur la barre, pas dans les tooltips. Les seuils s'appliquent à la
valeur arrondie affichée :

| Module | Normale | Verte | Orange | Rouge |
| --- | --- | --- | --- | --- |
| CPU, RAM, Swap, GPU | < 10 % | 10–32 % | 33–65 % | ≥ 66 % |
| Disque | < 21 % | 21–32 % | 33–65 % | ≥ 66 % |
| Load | ≤ 10 % | 11–50 % | 51–90 % | > 90 % |
| Réseau | < 10 KiB/s | 10–499 KiB/s | 500–1000 KiB/s | > 1000 KiB/s |
| Batterie | ≥ 50 % | 20–49 % | 11–19 % | ≤ 10 % |
| Températures | < 40 °C | 40–49 °C | 50–59 °C | ≥ 60 °C |

Le LOAD n'est pas plafonné : il peut dépasser 100 % lorsque la file d'attente
est plus longue que le nombre de CPU. La batterie suit une logique inversée,
plus la valeur est basse, plus la couleur est alarmante. Les débits réseau
descendant et montant sont colorés indépendamment.

Les couleurs verte/orange/rouge proviennent du `colors.toml` du thème Omarchy
courant. Les icônes conservent la couleur normale de la barre, sauf l'icône de
batterie : dès que la machine est sur secteur (en charge ou seuil de charge
atteint), l'icône passe au bleu du thème tandis que la valeur conserve la
couleur normale de la barre. Sur batterie, la valeur suit les seuils ci-dessus.

Le toggle **Colors** du panneau désactive toutes ces couleurs : les valeurs
et l'icône bleue de la batterie reviennent à la couleur normale de la barre.
Il correspond à `showColors` dans `shell.json` (activé par défaut).

## Icône de batterie

L'icône suit le niveau par paliers de 10 % (icône vide à 0 % ; de 1 à 9 %,
icône 10 %) et l'état d'alimentation :

- **sur batterie** : batterie seule, remplie selon le niveau ;
- **en charge** : batterie avec éclair, icône bleue, valeur dans la couleur
  normale de la barre ;
- **branchée sans charge** (pleine ou seuil de charge atteint) : batterie
  suivie d'une prise, icône bleue, valeur dans la couleur normale de la barre.

L'état « branché » vient de `UPower.onBattery`, ce qui distingue une machine
simplement branchée d'une machine en train de charger. Le pourcentage, l'état
et la puissance sont fournis par les propriétés UPower : aucun script ni timer
n'est nécessaire, la barre réagit aux signaux D-Bus. UPower interroge le
matériel environ toutes les 30 s, donc le pourcentage peut évoluer à ce
rythme. La santé de la batterie vient du périphérique UPower réel (le
`DisplayDevice` agrégé la laisse vide) ; le nombre de cycles est lu dans sysfs
(`/sys/class/power_supply/*/cycle_count`) au démarrage puis toutes les 10
minutes.

## Alertes

Le module **Alerts** est activé par défaut ; il peut être désactivé dans Settings.
Quand il est actif, `alerts.sh` tourne toutes les 60 s et signale :

- les unités systemd en état `failed`, côté système et utilisateur (icône
  rouge) ;
- les zombies de plus de **60 s** (icône orange).

Il apparaît à l'extrême droite, après Battery, avec une icône seule (sans
compteur), et uniquement tant qu'une alerte existe. Le tooltip liste les unités
en échec sous un titre `systemd` centré en minuscules, puis `systemd --user`,
puis `proc zombie` ; une ligne vide sépare les sections. Avec **Colors**
désactivé, l'icône reprend la couleur normale de la barre.

## Uptime

Le module **Uptime** est activé par défaut et peut être désactivé dans
Settings. Il lit `/proc/uptime` toutes les 5 s. La barre affiche `42m` sous une
heure, puis `3h42` ; le tooltip affiche `3h 42m`.

## Performances

Mesure sur deux fenêtres de 5 minutes, machine au repos, écran de veille et
verrouillage désactivés (Apple M2 Pro, Omarchy 4.0.3, Quickshell 0.3.2) :

| Scénario | CPU `quickshell` (1 cœur) | RSS moyen | Réveils / 5 min |
| --- | --- | --- | --- |
| Sans YASSM | 2,413 % | 736 Mio | 27 385 |
| Avec YASSM | 2,447 % | 750 Mio | 29 575 |
| **Surcoût** | **+0,034 point** | **+14 Mio** | **+2 190** |

Auxquels s'ajoutent les scripts éphémères (CPU mesuré sur 50 exécutions) :

| Script | CPU / exécution | Fréquence | CPU / minute |
| --- | --- | --- | --- |
| `temperature.sh` | 11,0 ms | 6×/min | 66 ms |
| `findmnt` | 2,0 ms | 6×/min | 12 ms |
| `alerts.sh` | ~110 ms | 1×/min | 110 ms |
| `cpu-freq.sh` | 3,0 ms | 12×/min | 36 ms |
| `wifi-freq.sh` | 8,0 ms | 2×/min (sans fil seulement) | 16 ms |
| Batterie (UPower) | 0 | événementiel | 0 |

**Surcoût total ≈ 0,16 % d'un cœur, ~14 Mio de RSS, aucun processus
résident.** YASSM est donc très performant : pas de polling batterie (UPower
est événementiel), une seule série de mesures partagée entre toutes les barres,
et la plupart des tooltips ne lancent aucun processus.

`findmnt` peut rester ~100 ms en attente d'I/O sur un montage réseau
(`/media/NAS` ici) ; la commande est encadrée par `timeout 5`, donc un montage
mort ne peut pas figer le module disque.

Le module réseau lit `/proc/net/dev` à chaque tick rapide ; `/proc/net/route`
et `/proc/net/ipv6_route` sont relus toutes les 5 s, sans processus.

Les périphériques de swap sont relus depuis `/proc/swaps` toutes les 5 s, et
`mm_stat` toutes les 10 s par zram, également sans processus.

Le tooltip CPU lit des snapshots de `/proc/<pid>/stat` (aucun processus) pour
des deltas instantanés ; seul le tooltip RAM utilise `ps` (RSS).

Température, disque, swap/ZRAM et alertes ne sont échantillonnés que si au
moins une barre a le module correspondant activé ; les masquer arrête
complètement les scripts. Les ventilateurs sont relevés par le même scan que
les températures (`temperature.sh`), donc sans processus supplémentaire.

`alerts.sh` tourne toutes les 60 s (systemd système/utilisateur + scan des
zombies), uniquement si Alerts est activé.

La pression PSI (`/proc/pressure/memory`, `/proc/pressure/io`),
`/proc/diskstats`, `/proc/net/wireless` et `/proc/uptime` sont lus toutes les
5 s sans lancer de processus. `cpu-freq.sh` relève le `scaling_cur_freq` de
chaque cœur toutes les 5 s. Le SSID vient du service NetworkManager via
D-Bus (ni processus ni interrogation), le niveau du signal est lu dans
`/proc/net/wireless` toutes les 5 s, et `wifi-freq.sh` demande la fréquence
associée à `iw` toutes les 30 s, uniquement si la liaison est sans fil. Les
adresses LAN et publique ne sont récupérées qu'à l'ouverture du tooltip NET en
mode extended : `ip -4` coûte ~3 ms, et <https://api.ipify.org> n'est
interrogé qu'une fois toutes les 5 minutes (une requête HTTPS, rien d'autre
n'est envoyé).

## Vérifications

```bash
./check.sh
```

Le script valide le manifeste, vérifie la syntaxe des scripts shell et la
cohérence des versions, contrôle les contrats JSON/température, lance
`shellcheck` si disponible et `qmllint` (Qt 6) avec une arborescence d'import
`qs.Commons`/`qs.Ui` correcte.

## GPU

Sources utilisées, dans l'ordre :

1. `/sys/class/drm/*/device/gpu_busy_percent` ;
2. `nvidia-smi` ;
3. sinon `GPU --%`.

### Apple Silicon / Asahi

Sur une machine Apple Silicon avec le pilote `asahi` (AGX), aucune mesure
d'occupation GPU n'est actuellement exposée par le système :

- pas de `gpu_busy_percent` ;
- pas de `devfreq` ni de fréquence GPU exposée ;
- pas de statistiques `drm-engine-*` dans `/proc/<pid>/fdinfo` ;
- pas de capteur de puissance GPU dédié ;
- le pilote n'expose pas de compteur d'utilisation via debugfs/sysfs.

Les outils existants ne couvrent pas ce cas : `btop` est compilé sans support
GPU, `nvtop` ne supporte Apple que sous macOS (Metal), et `asitop`/`macmon`
reposent sur `powermetrics`, également macOS uniquement. YASSM affiche donc
`GPU --%` sur cette configuration, plutôt qu'une valeur inventée.

## Mise à jour

Le dépôt distant est :

```text
https://github.com/jotenakis2/yassm.git
```

`omarchy plugin update` peut donc être utilisé. Sinon, remplacez les fichiers
manuellement puis relancez `omarchy plugin validate` et
`omarchy-shell shell rescanPlugins`.

Aucun fichier de configuration à migrer : les réglages sont dans `shell.json`.

## Désinstallation

```bash
omarchy plugin disable io.github.jotenakis2.yassm
omarchy plugin remove io.github.jotenakis2.yassm
```

`disable` retire le widget de la barre en conservant les fichiers. Comme le
dossier est un dépôt Git, `remove` supprime le dossier : pensez à pousser le
dépôt ou à conserver une archive avant.

## Licence

MIT — voir `LICENSE`.
