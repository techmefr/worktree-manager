---
name: worktree-manager
description: Créer un git worktree pour une tâche, et lister/nettoyer les worktrees dont la branche a une MR GitLab mergée. Déclencheurs : "crée un worktree", "nettoie les worktrees", "worktree pour <ticket>".
---

# Worktree Manager

Outil autonome (bash + glab + python3, aucune dépendance externe) pour gérer les worktrees
git au quotidien : création à la demande, et repérage de ceux à nettoyer une fois la MR mergée.

Prérequis : `glab` installé et authentifié sur l'instance GitLab du repo (`glab auth status`),
`python3` disponible.

## Créer un worktree

```bash
scripts/wt-create.sh <nom-branche> [chemin-du-repo] [branche-de-base]
```

- Crée un dossier `wt-<repo>-<branche>` à côté du repo principal.
- Détecte la branche de base (HEAD distant) si non précisée.
- Crée la branche localement si elle n'existe pas encore, à partir d'`origin/<base>`.
- Si `package-lock.json`/`composer.lock` sont identiques à ceux du repo principal, symlink
  `node_modules`/`vendor` depuis le repo principal au lieu de les laisser vides (pas de
  réinstall inutile). Si un lockfile diffère, l'affiche en clair : installer normalement dans
  ce cas précis, ne jamais symlinker malgré tout.

## Lister le statut des worktrees (MR mergée ou non)

```bash
scripts/wt-clean.sh [chemin-du-repo]
```

Affiche un tableau `worktree | branche | statut MR` (`none` / `opened` / `closed` / `merged`).
Les lignes `merged` sont candidates au nettoyage.

**Important : ce script ne supprime jamais rien tout seul.** Il liste, et donne les deux
commandes à lancer à la main (ou à faire confirmer par l'agent) pour chaque worktree à
supprimer :

```bash
git -C <repo-principal> worktree remove <chemin>
git -C <repo-principal> branch -D <branche>
```

## Utilisation par un agent Claude Code

Quand cette skill est invoquée :
1. Pour une demande de création (`crée un worktree pour <ticket>`), lancer `wt-create.sh`
   avec le nom de branche fourni (ou déduit du ticket) et rapporter le chemin créé, ainsi que
   ce qui a été fait pour `node_modules`/`vendor` (symlinké, ou à installer si lockfile différent).
2. Pour une demande de nettoyage (`nettoie les worktrees`), lancer `wt-clean.sh`, présenter le
   tableau, et **ne supprimer une entrée `merged` qu'après confirmation explicite de
   l'utilisateur pour cette entrée précise** — jamais en boucle silencieuse, même en tâche de
   fond.
3. Ne jamais forcer un symlink de dépendances si `wt-create.sh` a signalé un lockfile différent
   — laisser l'utilisateur installer normalement dans ce cas.

## Automatiser la vérification (optionnel, via /loop)

Pour une vérification périodique sans avoir à y penser, lancer dans Claude Code :

```
/loop 45m /worktree-manager clean
```

Ça relance `wt-clean.sh` toutes les 45 minutes et rapporte les worktrees dont la MR vient de
passer en `merged`. La suppression reste confirmée à chaque fois — le loop ne fait jamais le
ménage tout seul.
