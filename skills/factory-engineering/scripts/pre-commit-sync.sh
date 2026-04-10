#!/usr/bin/env bash
# Pre-commit hook: syncs canonical .claude/ folders to IDE-specific locations.
# Install: cp pre-commit-sync.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
# Or append the body of this script to an existing pre-commit hook.

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"

# Find sync-ide.sh in common locations
SYNC_SCRIPT=""
for candidate in \
  "$REPO_ROOT/.claude/skills/factory-engineering/scripts/sync-ide.sh" \
  "$REPO_ROOT/skills/factory-engineering/scripts/sync-ide.sh"; do
  if [[ -f "$candidate" ]]; then
    SYNC_SCRIPT="$candidate"
    break
  fi
done

if [[ -z "$SYNC_SCRIPT" ]]; then
  # Script not found; skip silently
  exit 0
fi

cd "$REPO_ROOT"

# Detect installed IDEs
detected=$(bash "$SYNC_SCRIPT" --detect 2>/dev/null || true)
if [[ -z "$detected" || "$detected" == *"No IDE directories"* ]]; then
  exit 0
fi

ide_list=$(echo "$detected" | tr '\n' ',' | sed 's/,$//')

echo "Pre-commit: syncing canonical folders to IDE directories ($ide_list)..."
bash "$SYNC_SCRIPT" --ide "$ide_list" --repo-root "$REPO_ROOT"

# Stage synced IDE directories
for ide_dir in .cursor .windsurf .kilocode .agent; do
  if [[ -d "$REPO_ROOT/$ide_dir" ]]; then
    git add "$REPO_ROOT/$ide_dir" 2>/dev/null || true
  fi
done
