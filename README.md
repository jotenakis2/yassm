# YASSM — Yet Another Simple System Monitor

Version 1.4.5

Widget de barre Omarchy affichant CPU, RAM, swap, charge système, température,
GPU et usage de la partition racine.

Dépôt prévu : <https://github.com/jotenakis2/yassm>

## Modules

| Module | Source | Rafraîchissement |
| --- | --- | --- |
| CPU | `/proc/stat` | 1 s |
| RAM | `/proc/meminfo` (`MemAvailable`) | 1 s |
| Swap | `/proc/meminfo` | 1 s |
| Load average | `/proc/loadavg`, normalisée par le nombre de CPU, sans plafond à 100 % | 1 s |
| GPU | `nvidia-smi` ou `gpu_busy_percent` sysfs | 10 s |
| Disque | `findmnt` (racine pour la barre, tous les FS dans le tooltip) | 15 s |
| Batterie | `/sys/class/power_supply` (partagé) | 10 s |
| Température | toutes les températures normales, triées | 10 s |

Le swap est masqué lorsque la machine n'a pas de swap actif. Le GPU affiche
`--%` lorsqu'aucune source fiable n'est disponible.

## Architecture

- `lib/SystemMetrics.qml` est un singleton partagé : un seul échantillonneur
  `/proc` et un seul `findmnt` pour toutes les instances de barre, y compris
  sur plusieurs écrans.
- `SettingsPanel.qml` est chargé à la demande au premier clic, puis conservé
  pour les ouvertures suivantes. Ses contrôles sont des `Toggle`/`ToggleSwitch`
  Omarchy, avec les polices, couleurs et espacements du thème courant.
- Le GPU reste géré par le widget, conformément à la limite actuelle du
  support Asahi.

## Prérequis

- Omarchy 4.x avec son shell Quickshell.
- `bash`, `find`, `sort` et `findmnt` (util-linux).
- Une police Nerd Font pour les icônes.
- Optionnel : `nvidia-smi` pour les GPU NVIDIA.

## Installation

```bash
unzip yassm.zip -d "$HOME/.config/omarchy/plugins/"
omarchy plugin validate "$HOME/.config/omarchy/plugins/io.github.jotenakis2.yassm"
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.jotenakis2.yassm --section left
```

Le `chmod +x` n'est pas nécessaire : les scripts sont lancés via `bash`.
La dernière commande place le widget dans la section `left` de la barre ;
adaptez `--section` (`left`, `center`, `right`) selon votre préférence.

## Panneau de configuration

Un clic sur le widget ouvre un panneau permettant d'activer ou de désactiver :

- CPU
- Load
- GPU
- Memory
- Swap
- Disk (`/`)
- Battery
- Temperature

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
  "showDisk": true
}
```

Toutes les clés sont optionnelles ; les valeurs absentes valent `true`.

Le panneau expose aussi les fonctions IPC `open`, `close`, `toggle`, `show` et
`hide` sur la cible `io.github.jotenakis2.yassm`, et respecte le contrat
`open()`/`close()`/`opened` utilisé par la barre Omarchy.

## Tooltips

Le survol d'un module affiche une infobulle contextuelle :

- **Load** : charge réelle non normalisée sur 1, 5 et 15 minutes, en colonnes
  alignées ;
- **RAM** : mémoire utilisée / mémoire totale en GiB ;
- **Swap** : swap utilisé / swap total en GiB. Si ZSWAP est utilisé, un bloc
  `ZSWAP` affiche la taille compressée, la taille originale et le ratio de
  compression ;
- **Disk** : une ligne par système de fichiers réel détecté, en GiB, avec le
  pourcentage. Les pseudo-filesystems (`proc`, `sysfs`, `tmpfs`, `cgroup`,
  etc.) sont ignorés. Les points de montage qui partagent le même
  device/source sont dédupliqués : sur un root btrfs avec subvolumes, `/home`
  et `/var/log` n'apparaissent donc pas séparément de `/` ;
- **Temperature** : toutes les températures normales trouvées, triées de la
  plus élevée à la plus basse, avec le nom du capteur entre parenthèses ; la
  barre affiche la plus élevée ;
- **Battery** : pourcentage, état, temps restant ou temps de charge, et
  puissance instantanée quand le noyau la fournit, avec la direction
  (`draw` en décharge, `charge` en charge) ;
- **CPU** et **GPU** : pourcentage courant.

Les infobulles ne lancent aucun processus supplémentaire : les valeurs sont
formatées à la demande, uniquement pendant le survol, et la mise à jour de
segment se fait sans recréer d'objets visuels.

## Couleurs de la barre

Uniquement sur la barre, pas dans les tooltips :

- valeurs en pourcentage : normale sous 10 %, verte sous 33 %, orange sous
  66 %, rouge au-delà ;
- charge système (load) : normale jusqu'à 10 %, verte au-delà, orange au-delà
  de 50 %, rouge au-delà de 90 % ; la valeur n'est pas plafonnée et peut donc
  dépasser 100 % lorsque la file d'attente dépasse le nombre de CPU ;
- températures : normale sous 40 °C, verte sous 50 °C, orange sous 60 °C,
  rouge au-delà ;
- batterie : rouge sous 10 %, orange sous 20 %, verte sous 50 %, normale
  au-dessus.

Les couleurs verte/orange/rouge proviennent du `colors.toml` du thème Omarchy
courant. Les icônes conservent la couleur normale de la barre, à une exception
près : l'icône de batterie passe au bleu du thème pendant la charge. Seules les
valeurs sont colorées par les seuils.

## Icône de batterie

L'icône suit le niveau par paliers de 10 % (batterie vide sous 10 %) et l'état
d'alimentation :

- **sur batterie** : batterie seule, remplie selon le niveau ;
- **en charge** : batterie avec éclair, icône teintée du bleu du thème ;
- **branchée sans charge** (pleine ou seuil de charge atteint) : batterie
  suivie d'une prise.

L'état « branché » vient du champ `online` de l'alimentation secteur dans
`/sys/class/power_supply`, ce qui distingue une machine simplement branchée
d'une machine en train de charger.

## Vérifications

```bash
./check.sh
```

Le script valide le manifeste, vérifie la syntaxe du script GPU, lance
`shellcheck` si disponible et `qmllint` (Qt 6) sur les fichiers QML.

## GPU

Sources utilisées :

1. `nvidia-smi` ;
2. `/sys/class/drm/*/device/gpu_busy_percent` ;
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

Le dépôt local est initialisé avec Git. Le remote prévu est :

```text
https://github.com/jotenakis2/yassm.git
```

Une fois le dépôt GitHub créé et poussé, `omarchy plugin update` pourra
fonctionner ; sinon, remplacez les fichiers manuellement puis relancez
`omarchy plugin validate` et `omarchy-shell shell rescanPlugins`.

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
