#!/usr/bin/env python3
"""Reads glab mr list JSON on stdin, prints the most relevant MR state.

Usage: glab mr list --source-branch=<branch> -A --output json | wt-mr-status.py
Prints one of: none / opened / closed / merged
"""
import json
import sys

try:
    mrs = json.load(sys.stdin)
except json.JSONDecodeError:
    print("none")
    sys.exit(0)

if not mrs:
    print("none")
    sys.exit(0)

# Prefer a merged MR if several exist for the same branch, otherwise the most recent.
merged = [mr for mr in mrs if mr.get("state") == "merged"]
if merged:
    print("merged")
    sys.exit(0)

mrs_sorted = sorted(mrs, key=lambda mr: mr.get("updated_at", ""), reverse=True)
print(mrs_sorted[0].get("state", "none"))
