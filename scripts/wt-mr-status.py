#!/usr/bin/env python3
"""Reads `glab mr list` or `gh pr list` JSON on stdin, prints the most relevant state.

Usage:
  glab mr list --source-branch=<branch> -A --output json | wt-mr-status.py
  gh pr list --head <branch> --state all --json state,updatedAt | wt-mr-status.py

Prints one of: none / opened / closed / merged
(gh uses OPEN/CLOSED/MERGED, glab uses opened/closed/merged — normalized to lowercase here.)
"""
import json
import sys

try:
    items = json.load(sys.stdin)
except json.JSONDecodeError:
    print("none")
    sys.exit(0)

if not items:
    print("none")
    sys.exit(0)

def state_of(item):
    return str(item.get("state", "")).lower()

def updated_of(item):
    return item.get("updated_at") or item.get("updatedAt") or ""

# Prefer a merged MR/PR if several exist for the same branch, otherwise the most recent.
merged = [item for item in items if state_of(item) == "merged"]
if merged:
    print("merged")
    sys.exit(0)

items_sorted = sorted(items, key=updated_of, reverse=True)
print(state_of(items_sorted[0]) or "none")
