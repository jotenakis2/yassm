# YASSM — Performances

[English](performance.md) | **Français**

YASSM est un widget de barre : il doit rester aussi discret dans `top` qu'à
l'écran. Cette page documente la méthode de mesure, le coût réel et les choix
qui l'expliquent.

Toutes les valeurs ci-dessous ont été relevées sur la machine de référence, au
repos, sans tooltip ouvert, écran de veille et verrouillage désactivés.

| | |
| --- | --- |
| Machine | Apple M2 Pro, 12 cœurs (aarch64) |
| OS | Omarchy 4.0.3 |
| Shell | Quickshell 0.3.2 |
| Noyau | 7.1.12 |
| YASSM | 1.19.x |

## En bref

- **Aucun processus résident.** Chaque script auxiliaire est éphémère.
- **Surcoût ≈ 0,8 point d'un cœur** (≈ 0,07 % de la capacité 12 cœurs de la
  machine) au refresh par défaut de 1 s, et ≈ 0,4 point à 5 s.
- **Coût absolu de YASSM activé** ≈ 1,4 point d'un cœur (≈ 0,12 % de la
  machine), dont l'essentiel est la mise à jour de la barre à 1 Hz.
- **~15 lancements de scripts par minute** au repos (température, disque,
  alertes, fréquence Wi-Fi), et **0** pour la fréquence CPU hors de son
  tooltip.
- **Aucun polling batterie** : UPower et NetworkManager sont événementiels via
  D-Bus.

## Comment c'est mesuré

### Processus du shell

Le CPU est la somme du temps d'exécution de **tous** les threads du processus
`quickshell`, lu dans `/proc/<pid>/task/*/schedstat` (nanosecondes) — pas
seulement le thread principal, et pas l'échantillonnage de `top`. Les réveils
sont la somme de `voluntary_ctxt_switches` et `nonvoluntary_ctxt_switches`
dans `/proc/<pid>/status`.

Chaque état a été mesuré sur deux fenêtres de 90–120 s, en alternance A/B,
puis moyenné. L'alternance est importante : le shell fait aussi tourner
d'autres plugins et la machine a une activité de fond, donc une fenêtre isolée
dérive de quelques dixièmes de point.

```bash
pid=$(pgrep -x quickshell | head -1)
sum=0
for f in /proc/$pid/task/*/schedstat; do read -r v _ <"$f"; sum=$((sum + v)); done
echo "$sum"   # relire après N secondes : CPU% = delta / (N * 1e9) * 100
```

### Scripts

Chaque script a été exécuté 10 fois et son **temps CPU enfant** (user +
system) additionné avec `os.times()` de Python, plus précis que le temps réel
pour des processus très courts. Le temps réel a été recoupé avec `hyperfine`.

```python
import os, subprocess
u = s = 0.0
for _ in range(10):
    before = os.times()
    subprocess.run(["./temperature.sh"], stdout=subprocess.DEVNULL)
    after = os.times()
    u += after.children_user - before.children_user
    s += after.children_system - before.children_system
print((u + s) / 10 * 1000, "ms CPU/exécution")
```

## Surcoût du shell

| Scénario | CPU `quickshell` (1 cœur) | Réveils / min |
| --- | --- | --- |
| Sans YASSM | 0,60 % | ~1 120 |
| Avec YASSM, refresh 1 s (défaut) | 1,20 % | ~1 950 |
| Avec YASSM, refresh 5 s | 0,80 % | ~1 680 |
| **Surcoût à 1 s** | **+0,60 point** | **+830** |
| **Surcoût à 5 s** | **+0,20 point** | **+560** |

Le surcoût représente **0,05 % de la capacité totale** de la machine à 1 s
(0,60 point d'un cœur sur 12) et **0,017 %** à 5 s. Pour situer, l'empreinte
absolue de YASSM activé est de 1,20 % d'un cœur, soit 0,10 % de la machine.

Le coût est dominé par la boucle d'une seconde : quatre lectures `/proc`, mises
à jour de bindings et mise en page du texte des modules visibles. C'est
pourquoi le curseur **Refresh** (1–5 s) a un effet aussi net : à 5 s, le shell
baisse d'un tiers.

Les réveils suivent la même courbe : +830/min à 1 s (≈ 14/s), +560/min à 5 s.

## Coût des scripts

Au repos (aucun tooltip), machine de référence :

| Script | CPU / exécution | Fréquence | CPU / minute |
| --- | --- | --- | --- |
| `temperature.sh` (températures + ventilateurs) | 14 ms | 6×/min | 85 ms |
| `alerts.sh` (systemd + zombies) | 23 ms | 1×/min | 23 ms |
| `findmnt` (systèmes de fichiers locaux) | 1 ms | 6×/min | 6 ms |
| `wifi-freq.sh` | 6 ms | 2×/min (sans fil) | 12 ms |
| Cycles batterie (`sysfs`) | < 1 ms | 1×/10 min | < 0,1 ms |
| **Total** | | | **≈ 126 ms/min** |

≈ 126 ms de CPU par minute, soit **0,21 % d'un cœur** (0,018 % de la machine).
Aucun de ces processus ne survit entre deux exécutions.

À la demande uniquement :

| Action | Coût | Quand |
| --- | --- | --- |
| `proc-snapshot.sh` × 2 | 11 ms chacun | tooltip CPU ouvert (photo initiale + warmup de 1 s) |
| `cpu-freq.sh` | 3 ms | tooltip CPU ouvert, toutes les 5 s |
| `ps -eo … rss` | ~15 ms | tooltip RAM ouvert, toutes les 5 s |
| `ip -4 -o addr` | 3 ms | à chaque ouverture du tooltip NET |
| `curl https://api.ipify.org` | une requête HTTPS | tooltip NET ouvert, au plus toutes les 5 min |

## Total

| Composant | Points d'un cœur | Part de la machine 12 cœurs |
| --- | --- | --- |
| Boucle du shell (1 s) | +0,60 | 0,05 % |
| Scripts au repos | +0,21 | 0,018 % |
| **Surcoût total** | **≈ +0,8** | **≈ 0,07 %** |

Au refresh de 5 s, le surcoût total tombe à ≈ 0,4 point d'un cœur (≈ 0,03 % de
la machine).

## Pourquoi c'est économe

- **Un seul échantillonneur pour tout le shell.** `lib/SystemMetrics.qml` est
  un singleton : les configurations multi-écrans partagent les mêmes lectures
  `/proc` et les mêmes timers.
- **Échantillonnage selon les modules.** Chaque échantillonneur s'enregistre
  par liste de références et ne tourne que tant qu'au moins une barre affiche
  le module qui le consomme. Un module masqué arrête complètement ses lectures
  et ses timers.
- **Détails à la demande.** Listes de processus, fréquence CPU, adresses
  LAN/WAN et valeurs PSI utilisées uniquement par les tooltips sont
  récupérées à l'ouverture du tooltip, pas en tâche de fond. L'échantillonnage
  de la fréquence s'arrête dès que le tooltip se ferme.
- **Pas de polling quand le système peut pousser.** État et santé de la
  batterie, SSID et état du lien viennent d'UPower et de NetworkManager via
  D-Bus.
- **Chemins `/proc` sans processus.** Tout ce qui peut être une simple lecture
  de fichier (`/proc/stat`, `meminfo`, `loadavg`, `net/dev`, `pressure/*`,
  `diskstats`, `uptime`, état zswap) passe par un `FileView`, sans lancer de
  processus.
- **Scripts éphémères, avec timeouts.** `findmnt`, `ps`, `alerts.sh` et
  `temperature.sh` sont encadrés par `timeout` : un montage réseau mort ou une
  requête systemd bloquée ne peut pas figer le widget.
- **Scripts allégés.** Le scan des températures regroupe la résolution des
  liens de périphériques en un seul appel `readlink` (30 ms → 14 ms), et
  `alerts.sh` détecte les zombies avec `ps` + `awk` au lieu d'une boucle bash
  sur `/proc` (82 ms → 23 ms).

## Coûts acceptés

- Le refresh à 1 Hz est le choix de conception : un moniteur système qui se
  met à jour chaque seconde. Le passer à 2 s ou plus dans Settings réduit le
  surcoût du shell à peu près proportionnellement.
- Ouvrir le tooltip CPU coûte deux snapshots `/proc` espacés d'une seconde (le
  premier ne sert que de référence, car un pourcentage CPU instantané exige un
  delta), plus une lecture de fréquence de 3 ms.
- Le RSS n'est pas reporté ici : le processus du shell est partagé avec tous
  les autres plugins et sa taille résidente fluctue de plus que l'empreinte
  propre de YASSM (quelques Mo d'objets QML et un modèle de tooltip de 20
  lignes), donc tout chiffre isolé serait du bruit.
