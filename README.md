# Worktree Manager

Petit outil autonome pour gérer les git worktrees au quotidien : création à la demande, et
repérage de ceux dont la MR GitLab est mergée (donc nettoyables).

Aucune dépendance à un projet précis : ça marche sur n'importe quel repo git.

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

## Contenu du dossier

- `SKILL.md` — instructions pour un agent Claude Code (utilisé automatiquement si le dossier
  est dans `~/.claude/skills/`)
- `scripts/wt-create.sh` — création de worktree
- `scripts/wt-clean.sh` — listing + statut MR des worktrees
- `scripts/wt-mr-status.py` — parsing du JSON `glab mr list` (utilisé par `wt-clean.sh`)
