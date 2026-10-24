# Omarchy System Monitor

Widget de barre Omarchy affichant CPU, RAM, swap, charge système, GPU et usage
de la partition racine.

## Modules

| Module | Source | Rafraîchissement |
| --- | --- | --- |
| CPU | `/proc/stat` | 1 s |
| RAM | `/proc/meminfo` (`MemAvailable`) | 1 s |
| Swap | `/proc/meminfo` | 1 s |
| Load average | `/proc/loadavg`, normalisée par le nombre de CPU | 1 s |
| GPU | `nvidia-smi` ou `gpu_busy_percent` sysfs | 10 s |
| Disque `/` | `df -P /` | 15 s |

Le swap est masqué lorsque la machine n'a pas de swap actif. Le GPU affiche
`--%` lorsqu'aucune source fiable n'est disponible.

## Prérequis

- Omarchy 4.x avec son shell Quickshell.
- `bash`, `find`, `sort`, `df`, `awk`.
- Une police Nerd Font pour les icônes.
- Optionnel : `nvidia-smi` pour les GPU NVIDIA.

## Installation

```bash
unzip omarchy-system-monitor.zip -d "$HOME/.config/omarchy/plugins/"
omarchy plugin validate "$HOME/.config/omarchy/plugins/io.github.vous.system-monitor"
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.vous.system-monitor --section left
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

Les préférences sont enregistrées dans `~/.config/omarchy/shell.json`, dans
l'entrée de barre du widget. Il n'y a plus de fichier de configuration séparé.

Exemple d'entrée :

```json
{
  "id": "io.github.vous.system-monitor",
  "showCpu": true,
  "showMemory": true,
  "showSwap": true,
  "showGpu": true,
  "showLoad": true,
  "showDisk": true
}
```

Toutes les clés sont optionnelles ; les valeurs absentes valent `true`.

Le panneau expose aussi les fonctions IPC `open`, `close`, `toggle`, `show` et
`hide` sur la cible `io.github.vous.system-monitor`, et respecte le contrat
`open()`/`close()`/`opened` utilisé par la barre Omarchy.

## Sources GPU

1. `nvidia-smi`
2. `/sys/class/drm/*/device/gpu_busy_percent`
3. Aucune source : affichage de `GPU --%`

Il n'existe pas d'outil `asahi-gpu-top` : sur Apple Silicon/Asahi, le widget
utilise `gpu_busy_percent` si le noyau l'expose, sinon il affiche `--%`.

## Mise à jour

Le dépôt local est initialisé avec Git, mais aucun remote n'est configuré.
`omarchy plugin update` ne fonctionne qu'avec un checkout Git possédant un
remote : ajoutez-en un, puis utilisez `git pull`, `omarchy plugin validate` et
`omarchy-shell shell rescanPlugins`. Sans remote, remplacez les fichiers
manuellement puis relancez la validation et le scan.

Aucun fichier de configuration à migrer : les réglages sont dans
`shell.json`.

## Désinstallation

```bash
omarchy plugin disable io.github.vous.system-monitor
omarchy plugin remove io.github.vous.system-monitor
```

`disable` retire le widget de la barre en conservant les fichiers. Comme le
dossier est désormais un dépôt Git, `remove` supprime le dossier (il ne le
sauvegarde plus automatiquement) : pensez à pousser le dépôt ou à conserver
l'archive ZIP avant.

## Licence

MIT — voir `LICENSE`.
