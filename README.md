# Worktree Manager

Petit outil autonome pour gérer les git worktrees au quotidien : création à la demande, et
repérage de ceux dont la MR GitLab est mergée (donc nettoyables).

Aucune dépendance à un projet précis : ça marche sur n'importe quel repo git.

## C'est quoi un worktree (le cours en 2 minutes)

Normalement, un repo git = un seul dossier = une seule branche checkoutée à la fois. Si tu dois
changer de branche, tu fais `git checkout` et le contenu du dossier change à ta place. Ça marche,
mais dès que tu as du travail en cours (fichiers modifiés non commités) et qu'on te demande de
partir sur autre chose (urgence, review à corriger), c'est la galère : stash, checkout, stash pop,
en espérant ne rien oublier.

Un `git worktree`, c'est un **deuxième dossier**, branché sur ce même repo (même historique,
mêmes commits, mêmes objets git en interne), mais avec sa **propre branche checkoutée** dedans.
Concrètement :

```bash
git worktree add ../wt-mon-repo-STK-1234 -b STK-1234-ma-feature origin/develop
```

crée un dossier `../wt-mon-repo-STK-1234` à côté du repo, déjà sur la bonne branche, prêt à
travailler — sans toucher au dossier principal. C'est un checkout en plus, **pas** un clone
complet : pas de nouveau `.git` à télécharger, juste un pointeur de plus dans le repo existant.

**Avantages :**
- Travailler sur plusieurs branches/tâches en même temps, chacune dans son propre dossier, sans
  jamais perdre l'état de ce qu'on avait en cours ailleurs.
- Un environnement isolé par tâche (containers, `node_modules`, fenêtre IDE ouverte).
- Revenir sur une urgence sans toucher à la branche sur laquelle on est déjà en train de bosser.

**Inconvénients / pièges :**
- Ça duplique tout ce qui n'est pas versionné : `node_modules`, `.env`, volumes Docker... donc
  ça consomme de l'espace disque et demande de re-set up l'environnement à chaque worktree.
- Les worktrees s'accumulent vite si on ne les nettoie pas une fois la tâche mergée — c'est
  précisément le problème que cet outil adresse.
- Sur les stacks Xefi (tout en Docker Compose), faire tourner deux worktrees d'un même projet
  **en même temps** fait collisionner les ports/volumes — voir la section dédiée ci-dessous.

## Mon approche

Un worktree = une tâche = une branche, créé à côté du repo principal (`wt-<repo>-<branche>`)
plutôt que dans un sous-dossier caché, pour pouvoir naviguer dedans comme un dossier normal.
Je ne supprime jamais un worktree à l'aveugle : je vérifie d'abord que sa MR est bien mergée sur
GitLab, puis je supprime à la main. Rien n'est automatisé côté suppression — l'outil liste et
propose, il ne décide jamais à ma place.

## Faire tourner la stack d'un worktree (ports et URLs)

Le worktree isole ton **code**, pas ton **environnement d'exécution**. Sur les projets Xefi
(Laravel Sail, Nuxt, tout en Docker Compose), chaque stack lit des ports fixes dans son `.env`
(`APP_PORT`, `FORWARD_DB_PORT`, etc.). Si tu lances la stack du worktree principal **et** celle
d'un worktree en même temps, elles essaient d'écouter sur les **mêmes ports** → collision, l'une
des deux ne démarre pas ou écrase l'autre.

**Ce que ça veut dire en pratique aujourd'hui :**
- **Une seule stack Docker à la fois par projet.** Avant de lancer la stack d'un worktree,
  arrête celle du repo principal (ou de l'autre worktree) sur ce même projet.
- Si tu as vraiment besoin de deux stacks du même projet en parallèle, il faut modifier les
  ports dans le `.env` du worktree (offset manuel, ex: `APP_PORT=8283` au lieu de `8282`) — à
  faire à la main, projet par projet, pas automatisé pour l'instant.
- Certains projets (`platform`, `pilota`) ont déjà un Traefik devant, qui route par nom plutôt
  que par port — sur ceux-là le souci est moins présent, mais vérifie quand même avant de
  lancer deux stacks en parallèle.
- Utilise toujours l'URL/le port définis par le `.env` **du worktree où tu es**, pas celui du
  repo principal — sinon tu te retrouves à appeler l'API du mauvais worktree sans t'en rendre
  compte (bug fantôme classique).

Ce point de friction (pas de vraie isolation réseau par worktree) est justement ce que l'outil
plus complet mentionné plus bas doit résoudre, via un système d'URLs propres par
projet/worktree sans gestion manuelle de ports.

## Installation

**Prérequis :**
- `glab` installé et authentifié sur l'instance GitLab du repo (`glab auth status` doit être vert)
- `python3` disponible

**Étapes :**

```bash
git clone https://github.com/techmefr/worktree-manager.git
chmod +x worktree-manager/scripts/*.sh worktree-manager/scripts/*.py
```

Si tu utilises Claude Code, clone-le directement dans `~/.claude/skills/` pour que la skill soit
disponible automatiquement :

```bash
git clone https://github.com/techmefr/worktree-manager.git ~/.claude/skills/worktree-manager
```

Pour mettre à jour plus tard : `git -C ~/.claude/skills/worktree-manager pull`.

Sinon, garde le dossier où tu veux et appelle les scripts directement avec leur chemin complet.

## Utilisation

### Créer un worktree pour une tâche

```bash
scripts/wt-create.sh <nom-branche> [chemin-du-repo] [branche-de-base]
```

- `<nom-branche>` : le nom de la branche à créer (ou existante)
- `[chemin-du-repo]` : optionnel, repo courant par défaut
- `[branche-de-base]` : optionnel, détecte automatiquement la branche par défaut du repo sinon

Exemple :
```bash
cd ~/mon-repo
~/.claude/skills/worktree-manager/scripts/wt-create.sh STK-1234-mon-ticket
```

Ça crée un dossier `wt-mon-repo-STK-1234-mon-ticket` juste à côté du repo, avec la branche déjà
checkoutée dessus.

### Voir quels worktrees peuvent être nettoyés

```bash
scripts/wt-clean.sh [chemin-du-repo]
```

Affiche un tableau `worktree | branche | statut MR` (`none` / `opened` / `closed` / `merged`).

**Le script ne supprime jamais rien tout seul.** Pour chaque ligne en `merged`, il suffit de
lancer à la main (depuis le repo principal) :

```bash
git worktree remove <chemin>
git branch -D <branche>
```

### Automatiser la vérification (Claude Code uniquement, optionnel)

Une fois la skill installée dans `~/.claude/skills/worktree-manager/` :

```
/loop 45m /worktree-manager clean
```

Relance `wt-clean.sh` toutes les 45 minutes et rapporte les worktrees passés en `merged`.
La suppression reste toujours confirmée à la main, même en tâche de fond — le loop ne fait
jamais le ménage tout seul.

## Et après ?

Cet outil reste volontairement simple (scripts bash, aucune interface). Je prépare en parallèle
un outil plus complet pour gérer les worktrees à plusieurs (état partagé en base, dashboard
visuel type Portainer pour voir tous les worktrees en cours, leur statut, les lancer/nettoyer
sans passer par la ligne de commande). Ce README sera mis à jour quand il sera prêt — en
attendant, `worktree-manager` fait le job au quotidien sans rien à installer de lourd.

## Contenu du dossier

- `SKILL.md` — instructions pour un agent Claude Code (utilisé automatiquement si le dossier
  est dans `~/.claude/skills/`)
- `scripts/wt-create.sh` — création de worktree
- `scripts/wt-clean.sh` — listing + statut MR des worktrees
- `scripts/wt-mr-status.py` — parsing du JSON `glab mr list` (utilisé par `wt-clean.sh`)
