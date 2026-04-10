#!/usr/bin/env bash
# Two-phase sync for canonical .claude/ folders and IDE-specific locations.
#
# Phase 1 — Reverse-sync (additive): pull new/changed files from IDE
#           locations back into canonical folders. No deletions.
# Phase 2 — Forward-sync (mirror): push canonical folders out to IDE
#           locations, deleting stale files in the targets.
#
# After both phases every location is identical and .claude/ is the
# single source of truth.
#
# Uses rsync when available; falls back to cp otherwise.
#
# Usage:
#   sync-ide.sh --detect
#   sync-ide.sh --ide cursor[,windsurf,kilocode,antigravity]
#   sync-ide.sh --ide cursor --method symlink
#   sync-ide.sh --migrate --ide cursor
#   sync-ide.sh --dry-run --ide cursor,windsurf

set -e

REPO_ROOT=
DETECT=
IDES=
MIGRATE=
DRY_RUN=
METHOD="copy"
TYPE="all"

# Canonical locations
canonical_commands=".claude/commands"
canonical_skills=".claude/skills"

# IDE-specific target paths
declare -A commands_map=(
  [cursor]=".cursor/commands"
  [windsurf]=".windsurf/workflows"
  [kilocode]=".kilocode/workflows"
  [antigravity]=".agent/workflows"
)
# Cursor reads .claude/skills directly; no sync needed for cursor skills
declare -A skills_map=(
  [windsurf]=".windsurf/skills"
  [kilocode]=".kilocode/skills"
  [antigravity]=".agent/skills"
)

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --detect            Print detected IDEs (no changes).
  --ide IDE[,IDE...]  Target IDEs: cursor, windsurf, kilocode, antigravity.
  --type TYPE         One of: commands, skills, all (default: all).
  --method METHOD     Sync method: copy (default) or symlink.
  --migrate           Convert existing symlinks to directory copies.
  --dry-run           Preview changes without modifying files.
  --repo-root PATH    Repository root (default: current directory).
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    --type)      TYPE="$2"; shift 2 ;;
    --method)    METHOD="$2"; shift 2 ;;
    --detect)    DETECT=1; shift ;;
    --ide)       IDES="$2"; shift 2 ;;
    --migrate)   MIGRATE=1; shift ;;
    --dry-run)   DRY_RUN=1; shift ;;
    -h|--help)   usage ;;
    *)           echo "Unknown option: $1" >&2; usage ;;
  esac
done

case "$TYPE" in
  commands|skills|all) ;;
  *) echo "Error: --type must be commands, skills, or all." >&2; usage ;;
esac
case "$METHOD" in
  copy|symlink) ;;
  *) echo "Error: --method must be copy or symlink." >&2; usage ;;
esac

if [[ -z "$REPO_ROOT" ]]; then REPO_ROOT="$(pwd)"; fi
REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"
cd "$REPO_ROOT"

# ─── Detect ───────────────────────────────────────────────────────────

if [[ -n "$DETECT" ]]; then
  detected=()
  [[ -d ".cursor" ]]   && detected+=(cursor)
  [[ -d ".windsurf" ]] && detected+=(windsurf)
  [[ -d ".kilocode" ]] && detected+=(kilocode)
  [[ -d ".agent" ]]    && detected+=(antigravity)
  if [[ ${#detected[@]} -eq 0 ]]; then
    echo "No IDE directories (.cursor, .windsurf, .kilocode, .agent) found in $REPO_ROOT"
  else
    printf '%s\n' "${detected[@]}"
  fi
  exit 0
fi

if [[ -z "$IDES" ]]; then
  echo "Error: specify --ide cursor[,windsurf,kilocode,antigravity] or run with --detect first." >&2
  usage
fi

# Normalize IDE list
IFS=',' read -ra IDE_LIST <<< "$IDES"
for i in "${!IDE_LIST[@]}"; do
  IDE_LIST[$i]="$(echo "${IDE_LIST[$i]}" | tr '[:upper:]' '[:lower:]' | xargs)"
  case "${IDE_LIST[$i]}" in
    cursor|windsurf|kilocode|antigravity|"") ;;
    *) echo "Error: unknown IDE '${IDE_LIST[$i]}'." >&2; exit 1 ;;
  esac
done

# ─── Sync helpers ─────────────────────────────────────────────────────

HAS_RSYNC=
command -v rsync &>/dev/null && HAS_RSYNC=1

# Remove symlink at path, replacing with nothing (caller will create dir).
remove_symlink_if_needed() {
  local path="$1"
  [[ -L "$path" ]] || return 0
  if [[ -n "$MIGRATE" ]]; then
    if [[ -n "$DRY_RUN" ]]; then
      echo "[DRY RUN] Would remove symlink $path"
    else
      rm "$path"
      echo "Migrated: removed symlink $path"
    fi
  else
    echo "Error: $path is a symlink. Use --migrate to convert to a copy." >&2
    return 1
  fi
}

# Phase 1: Reverse-sync — additive copy from $src/ into $dest/ (no deletes).
reverse_sync_dir() {
  local src="$1" dest="$2"
  [[ -d "$src" ]] || return 0
  [[ -L "$src" ]] && return 0   # skip symlinks (they point at canonical already)
  mkdir -p "$dest"
  if [[ -n "$DRY_RUN" ]]; then
    echo "[DRY RUN] Would reverse-sync $src -> $dest"
    return 0
  fi
  if [[ -n "$HAS_RSYNC" ]]; then
    rsync -a "$src/" "$dest/"
  else
    # cp fallback: walk src entries and copy individually to handle type
    # mismatches (e.g. file in dest where src has a directory, or vice versa).
    while IFS= read -r -d '' item; do
      local rel="${item#"$src"/}"
      local dest_item="$dest/$rel"
      if [[ -d "$item" ]]; then
        [[ -e "$dest_item" && ! -d "$dest_item" ]] && rm -f "$dest_item"
        mkdir -p "$dest_item"
      else
        [[ -e "$dest_item" && -d "$dest_item" ]] && rm -rf "$dest_item"
        mkdir -p "$(dirname "$dest_item")"
        cp "$item" "$dest_item"
      fi
    done < <(find "$src" -mindepth 1 -print0)
  fi
  echo "Reverse-synced: $src -> $dest"
}

# Phase 2: Forward-sync — mirror $src/ to $dest/ (deletes stale files).
forward_sync_dir() {
  local src="$1" dest="$2"
  [[ -d "$src" ]] || return 0
  if [[ -n "$DRY_RUN" ]]; then
    echo "[DRY RUN] Would forward-sync $src -> $dest"
    return 0
  fi
  local parent="${dest%/*}"
  mkdir -p "$parent"
  if [[ -n "$HAS_RSYNC" ]]; then
    mkdir -p "$dest"
    rsync -a --delete "$src/" "$dest/"
  else
    rm -rf "$dest"
    cp -R "$src" "$dest"
  fi
  echo "Forward-synced: $src -> $dest"
}

# ─── Symlink fallback (legacy) ────────────────────────────────────────

create_symlink() {
  local target_path="$1"
  local canonical_dir="$2"
  local parent_dir="${target_path%/*}"

  if [[ -L "$target_path" ]]; then
    local dest
    dest="$(readlink "$target_path")"
    if [[ "$dest" == "../$canonical_dir" || "$dest" == "$canonical_dir" ]]; then
      echo "Already a symlink: $target_path"
      return 0
    fi
    echo "Error: $target_path is a symlink but not to $canonical_dir." >&2
    return 1
  fi

  if [[ -d "$target_path" ]]; then
    echo "Error: $target_path already exists as a directory. Remove it or use copy mode." >&2
    return 1
  fi

  if [[ -n "$DRY_RUN" ]]; then
    echo "[DRY RUN] Would create symlink $target_path -> ../$canonical_dir"
    return 0
  fi

  mkdir -p "$canonical_dir"
  mkdir -p "$parent_dir"
  ln -s "../$canonical_dir" "$target_path"
  echo "Created symlink: $target_path -> ../$canonical_dir"
}

# ─── Main sync ────────────────────────────────────────────────────────

if [[ "$METHOD" == "symlink" ]]; then
  echo "WARNING: Symlink mode selected. Known limitations:"
  echo "  - Cursor has a documented bug where directory symlinks may not work"
  echo "  - Windows requires Developer Mode or elevated privileges for symlinks"
  echo "  - File-watching behavior varies across IDEs with symlinked directories"
  echo "  - Git handling of symlinks is inconsistent across platforms"
  echo "Consider using the default copy method instead."
  echo ""

  for ide in "${IDE_LIST[@]}"; do
    [[ -z "$ide" ]] && continue
    if [[ "$TYPE" == "commands" || "$TYPE" == "all" ]]; then
      [[ -n "${commands_map[$ide]}" ]] && create_symlink "${commands_map[$ide]}" "$canonical_commands"
    fi
    if [[ "$TYPE" == "skills" || "$TYPE" == "all" ]]; then
      [[ -n "${skills_map[$ide]}" ]] && create_symlink "${skills_map[$ide]}" "$canonical_skills"
    fi
  done
  exit $?
fi

# ── Copy mode: two-phase sync ────────────────────────────────────────

# Collect target dirs for selected IDEs
commands_targets=()
skills_targets=()
for ide in "${IDE_LIST[@]}"; do
  [[ -z "$ide" ]] && continue
  if [[ "$TYPE" == "commands" || "$TYPE" == "all" ]]; then
    [[ -n "${commands_map[$ide]}" ]] && commands_targets+=("${commands_map[$ide]}")
  fi
  if [[ "$TYPE" == "skills" || "$TYPE" == "all" ]]; then
    [[ -n "${skills_map[$ide]}" ]] && skills_targets+=("${skills_map[$ide]}")
  fi
done

# Handle symlink migration on all targets before syncing
for t in "${commands_targets[@]}" "${skills_targets[@]}"; do
  remove_symlink_if_needed "$t" || exit 1
done

# Ensure canonical dirs exist
mkdir -p "$canonical_commands" "$canonical_skills"

# Phase 1: Reverse-sync — gather changes from IDE locations into canonical
if [[ ${#commands_targets[@]} -gt 0 ]]; then
  for t in "${commands_targets[@]}"; do
    reverse_sync_dir "$t" "$canonical_commands"
  done
fi
if [[ ${#skills_targets[@]} -gt 0 ]]; then
  for t in "${skills_targets[@]}"; do
    reverse_sync_dir "$t" "$canonical_skills"
  done
fi

# Phase 2: Forward-sync — mirror canonical to all IDE locations
if [[ ${#commands_targets[@]} -gt 0 ]]; then
  for t in "${commands_targets[@]}"; do
    forward_sync_dir "$canonical_commands" "$t"
  done
fi
if [[ ${#skills_targets[@]} -gt 0 ]]; then
  for t in "${skills_targets[@]}"; do
    forward_sync_dir "$canonical_skills" "$t"
  done
fi
