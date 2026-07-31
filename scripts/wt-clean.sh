#!/usr/bin/env bash
# Liste les worktrees d'un repo git et leur statut de MR/PR (GitLab via glab, GitHub via gh).
# Usage : wt-clean.sh [chemin-du-repo]   (defaut: repertoire courant)
set -euo pipefail

REPO="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Erreur : $REPO n'est pas un repo git." >&2
    exit 1
fi

MAIN_WORKTREE="$(git -C "$REPO" worktree list --porcelain | awk '/^worktree /{print $2; exit}')"

REMOTE_URL="$(git -C "$MAIN_WORKTREE" remote get-url origin 2>/dev/null || echo "")"
if echo "$REMOTE_URL" | grep -qi "github.com"; then
    PROVIDER="github"
else
    PROVIDER="gitlab"
fi

echo "Repo principal : $MAIN_WORKTREE"
echo "Hebergeur       : $PROVIDER"
echo

printf "%-55s %-45s %s\n" "WORKTREE" "BRANCHE" "STATUT MR/PR"
printf "%-55s %-45s %s\n" "--------" "-------" "------------"

git -C "$REPO" worktree list --porcelain | awk '
    /^worktree / { path=$2 }
    /^branch /   { branch=$2; sub("refs/heads/", "", branch); print path"\t"branch }
' | while IFS=$'\t' read -r path branch; do
    if [ "$path" = "$MAIN_WORKTREE" ]; then
        continue
    fi

    git -C "$path" fetch origin >/dev/null 2>&1 || true

    if [ "$PROVIDER" = "github" ]; then
        json_cmd=(gh pr list --repo "$REMOTE_URL" --head "$branch" --state all --json state,updatedAt)
    else
        json_cmd=(glab mr list --source-branch="$branch" -A --output json)
    fi

    status=$( { "${json_cmd[@]}" 2>/dev/null || echo '[]'; } \
             | python3 "$SCRIPT_DIR/wt-mr-status.py" 2>/dev/null || echo "inconnu")

    printf "%-55s %-45s %s\n" "$path" "$branch" "$status"
done

echo
echo "-> Les lignes 'merged' sont candidates au nettoyage."
echo "   Pour supprimer un worktree + sa branche locale :"
echo "     git -C '$MAIN_WORKTREE' worktree remove <chemin>"
echo "     git -C '$MAIN_WORKTREE' branch -D <branche>"
echo "   Ne rien supprimer automatiquement : verifier chaque ligne avant."
