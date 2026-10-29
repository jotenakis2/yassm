# Panneau de configuration

**Clic droit** sur le widget pour ouvrir le panneau ; **clic gauche** lance ou
focus `btop` s'il est installé (Omarchy le rend flottant en 875×600). Si `btop`
n'est pas installé, le clic gauche ouvre le panneau à la place.

Le panneau permet d'activer ou de désactiver chaque module, et de les
réordonner en faisant glisser la poignée à gauche de chaque ligne (survoler
l'en-tête MODULES pour l'indication). L'ordre est
appliqué immédiatement à la barre et enregistré dans `moduleOrder`.

Chaque en-tête de section porte un chevron : cliquez dessus pour plier ou
déplier cette section indépendamment. Seul **Modules** est déplié par défaut ;
l'état n'est conservé que pendant la session et n'est pas écrit dans
`shell.json`.

**Langue** : les infobulles et le panneau suivent la locale de la session —
français si elle commence par `fr`, anglais sinon. Les intitulés techniques
cités dans cette page restent ceux de l'interface anglaise (`NET`, `SENSORS`,
`temperatures`, `fans`, `usage`…) ; l'interface française affiche `RÉSEAU`,
`CAPTEURS`, `températures`, `ventilateurs`, `utilisation`, etc.

**Modules**

- Uptime
- CPU
- Charge
- GPU
- Mémoire
- Swap
- Disque (`/`)
- Réseau
- Température
- Batterie
- Alertes

**Affichage**

- Cadres (encadrement des modules)
- Bordure des cadres (1–4 px ; par défaut, celle du thème)
- Rayon des coins (0–12 px ; 4 par défaut)
- Couleurs (seuils colorés et icône batterie bleue sur secteur)
- Données étendues dans les infobulles (fréquence par cœur, PSI, E/S disque, Wi-Fi, santé batterie)
- Entre les modules (espacement entre modules, 0–5 espaces ; 2 par défaut)
- Entre l'icône et la valeur (espace icône ↔ valeur, 0–3 espaces ; 1 par défaut)
- Processus affichés (processus espace-utilisateurs affichés, 1–20 ; 10 par défaut)

**Seuils**

- Utilisation (%) — CPU, RAM, swap et GPU
- Disque (%)
- Charge (%)
- Réseau (KiB/s)
- Batterie (%) — échelle inversée, survoler son titre pour l'explication
- Température (°C)

Chaque famille a trois champs numériques (vert, orange, rouge) : saisir une
valeur ou utiliser les flèches. L'ordre est toujours conservé, et l'échelle de
la batterie est inversée : normal au-dessus de Vert, puis vert, orange et
rouge à mesure que la valeur baisse.

**Intervalles**

- Échantillonnage rapide (métriques rapides : CPU, RAM, swap, charge, réseau, 1–5 s ; 1 par défaut)
- Échantillonnage lent (disque, température, uptime et GPU, 5–30 s ; 10 par défaut)

Toutes les cadences, y compris les fixes (alertes 60 s, cycles batterie 1 h) et
les échantillonneurs à la demande des tooltips, sont détaillées dans
[timers-fr.md](timers-fr.md).

Le curseur **Entre les modules** règle l'espacement entre les modules de 0 à 5
espaces (2 par défaut). Le curseur **Entre l'icône et la valeur** règle l'espace
entre l'icône et la valeur de chaque module de 0 à 3 espaces (1 par défaut,
soit 7,19 px). À 0, un écart minimal de 2 px est conservé.

Le curseur **Échantillonnage rapide** pilote la boucle rapide (CPU, RAM, swap,
charge, réseau). Les débits réseau utilisent le temps réel écoulé, donc
changer l'intervalle ne les fausse pas. Les listes de processus CPU et RAM
suivent l'**échantillonnage lent** tant que leur infobulle est ouverte. Le
curseur **Processus affichés** plafonne la liste des processus
espace-utilisateurs à 1–20
lignes (10 par défaut) ; la ligne `noyau` est toujours en plus. La liste CPU
est instantanée (deltas `/proc/<pid>/stat`), la RAM utilise le RSS de `ps`.
**Données étendues dans les infobulles** ajoute la fréquence CPU, la pression
PSI, les E/S disque, le signal Wi-Fi et la santé de la batterie à leurs
infobulles ; l'option est active par défaut. Survoler n'importe quelle ligne
de curseur affiche une infobulle avec ces explications. Le panneau défile
automatiquement si l'écran est trop court ; Échap le ferme.

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

Les clés de seuils suivent `<famille>Green`, `<famille>Orange` et
`<famille>Red` pour `percent`, `disk`, `load`, `net` et `battery`, plus
`tempWarm`, `tempHot` et `tempCritical`.

Toutes les clés sont optionnelles ; les valeurs absentes utilisent les défauts
ci-dessus. `moduleOrder` est la liste des clés de modules ci-dessus (`net`
couvre les deux boîtes de débit) ; une clé inconnue est ignorée et un nouveau
module absent de la liste est ajouté à la fin, donc un ancien `shell.json` ne
casse jamais la barre.

English version: [settings.md](settings.md).
