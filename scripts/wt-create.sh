#!/usr/bin/env bash
# Cree un nouveau worktree pour une branche/ticket, a cote du repo principal.
# Usage : wt-create.sh <nom-branche> [chemin-du-repo] [branche-de-base]
set -euo pipefail

BRANCH="${1:?Usage: wt-create.sh <nom-branche> [chemin-du-repo] [branche-de-base]}"
REPO="${2:-.}"

if ! git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Erreur : $REPO n'est pas un repo git." >&2
    exit 1
fi

REPO_ABS="$(git -C "$REPO" rev-parse --show-toplevel)"
REPO_NAME="$(basename "$REPO_ABS")"
PARENT_DIR="$(dirname "$REPO_ABS")"

BASE_BRANCH="${3:-}"
if [ -z "$BASE_BRANCH" ]; then
    BASE_BRANCH="$(git -C "$REPO_ABS" remote show origin 2>/dev/null | awk '/HEAD branch/{print $NF}')"
    BASE_BRANCH="${BASE_BRANCH:-main}"
fi

SLUG="$(echo "$BRANCH" | tr '/' '-')"
WT_PATH="$PARENT_DIR/wt-${REPO_NAME}-${SLUG}"

if [ -e "$WT_PATH" ]; then
    echo "Erreur : $WT_PATH existe deja." >&2
    exit 1
fi

git -C "$REPO_ABS" fetch origin "$BASE_BRANCH"

if git -C "$REPO_ABS" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git -C "$REPO_ABS" worktree add "$WT_PATH" "$BRANCH"
else
    git -C "$REPO_ABS" worktree add "$WT_PATH" -b "$BRANCH" "origin/$BASE_BRANCH"
fi

echo
echo "Worktree cree : $WT_PATH"
echo "Branche        : $BRANCH (base: $BASE_BRANCH)"
echo "-> cd $WT_PATH pour commencer a travailler."
