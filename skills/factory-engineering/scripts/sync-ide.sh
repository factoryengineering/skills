#!/usr/bin/env bash
# Sync canonical .claude/ folders to IDE-specific locations via file copying.
# Default method: copy (recommended). Symlinks available via --method=symlink.
# Run from repository root. See sync.md for full workflow.
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
COPY_EXISTING=
MIGRATE=
DRY_RUN=
METHOD="copy"
TYPE="all"

# Commands/workflows: canonical .claude/commands -> IDE-specific paths
cursor_commands=".cursor/commands"
windsurf_commands=".windsurf/workflows"
kilocode_commands=".kilocode/workflows"
antigravity_commands=".agent/workflows"
canonical_commands=".claude/commands"

# Skills: canonical .claude/skills -> IDE-specific paths
# Cursor reads .claude/skills directly; no sync needed for cursor skills
windsurf_skills=".windsurf/skills"
kilocode_skills=".kilocode/skills"
antigravity_skills=".agent/skills"
canonical_skills=".claude/skills"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --detect            Print detected IDEs (no changes).
  --ide IDE[,IDE...]  Target IDEs: cursor, windsurf, kilocode, antigravity.
  --type TYPE         One of: commands, skills, all (default: all).
  --method METHOD     Sync method: copy (default) or symlink.
  --copy-existing     Merge non-canonical target files into canonical folder before syncing.
  --migrate           Convert existing symlinks to file copies.
  --dry-run           Preview changes without modifying files.
  --repo-root PATH    Repository root (default: current directory).
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)     REPO_ROOT="$2"; shift 2 ;;
    --type)          TYPE="$2"; shift 2 ;;
    --method)        METHOD="$2"; shift 2 ;;
    --detect)        DETECT=1; shift ;;
    --ide)           IDES="$2"; shift 2 ;;
    --copy-existing) COPY_EXISTING=1; shift ;;
    --migrate)       MIGRATE=1; shift ;;
    --dry-run)       DRY_RUN=1; shift ;;
    -h|--help)       usage ;;
    *)               echo "Unknown option: $1" >&2; usage ;;
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

if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(pwd)"
fi
REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"
cd "$REPO_ROOT"

# --- Detect ---
if [[ -n "$DETECT" ]]; then
  detected=()
  [[ -d ".cursor" ]] && detected+=(cursor)
  [[ -d ".windsurf" ]] && detected+=(windsurf)
  [[ -d ".kilocode" ]] && detected+=(kilocode)
  [[ -d ".agent" ]] && detected+=(antigravity)
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

# Normalize IDEs to list
IFS=',' read -ra IDE_LIST <<< "$IDES"
for ide in "${IDE_LIST[@]}"; do
  ide="$(echo "$ide" | tr '[:upper:]' '[:lower:]' | xargs)"
  [[ -z "$ide" ]] && continue
  case "$ide" in
    cursor|windsurf|kilocode|antigravity) ;;
    *) echo "Error: unknown IDE '$ide'. Use cursor, windsurf, kilocode, antigravity." >&2; exit 1 ;;
  esac
done

# Warn about symlink limitations
if [[ "$METHOD" == "symlink" ]]; then
  echo "WARNING: Symlink mode selected. Known limitations:"
  echo "  - Cursor has a documented bug where directory symlinks may not work"
  echo "  - Windows requires Developer Mode or elevated privileges for symlinks"
  echo "  - File-watching behavior varies across IDEs with symlinked directories"
  echo "  - Git handling of symlinks is inconsistent across platforms"
  echo "Consider using the default copy method instead (omit --method or use --method=copy)."
  echo ""
fi

# --- Copy-based sync ---
copy_sync() {
  local canonical_dir="$1"
  local target_dir="$2"
  local parent_dir="${target_dir%/*}"

  # Handle existing symlink at target (migration)
  if [[ -L "$target_dir" ]]; then
    if [[ -n "$MIGRATE" ]]; then
      if [[ -n "$DRY_RUN" ]]; then
        echo "[DRY RUN] Would remove symlink $target_dir and create directory copy"
        return 0
      fi
      echo "Migrating: removing symlink $target_dir ..."
      rm "$target_dir"
    else
      echo "Warning: $target_dir is a symlink. Use --migrate to convert to a copy." >&2
      return 1
    fi
  fi

  # Handle non-canonical files in existing target
  if [[ -d "$target_dir" && -d "$canonical_dir" ]]; then
    local has_conflicts=0
    for f in "$target_dir"/*; do
      [[ -e "$f" ]] || continue
      local base
      base=$(basename "$f")
      if [[ ! -e "$canonical_dir/$base" ]]; then
        has_conflicts=1
        if [[ -n "$COPY_EXISTING" ]]; then
          if [[ -n "$DRY_RUN" ]]; then
            echo "[DRY RUN] Would merge $target_dir/$base -> $canonical_dir/$base"
          else
            cp -R "$target_dir/$base" "$canonical_dir/$base"
            echo "Merged non-canonical file: $base -> $canonical_dir/"
          fi
        else
          echo "Conflict: $target_dir/$base is not in $canonical_dir"
        fi
      fi
    done
    if [[ $has_conflicts -eq 1 && -z "$COPY_EXISTING" ]]; then
      echo "  Use --copy-existing to merge these files into $canonical_dir before syncing." >&2
      return 2
    fi
  fi

  if [[ ! -d "$canonical_dir" ]]; then
    if [[ -n "$DRY_RUN" ]]; then
      echo "[DRY RUN] Would create $canonical_dir (empty)"
    else
      mkdir -p "$canonical_dir"
    fi
    echo "Canonical folder $canonical_dir created (empty). Add files and re-run to sync."
    return 0
  fi

  if [[ -n "$DRY_RUN" ]]; then
    echo "[DRY RUN] Would sync $canonical_dir -> $target_dir"
    return 0
  fi

  # Sync: mirror canonical to target
  mkdir -p "$parent_dir"
  mkdir -p "$target_dir"
  # Remove files in target that are not in canonical (clean sync)
  for f in "$target_dir"/*; do
    [[ -e "$f" ]] || continue
    local base
    base=$(basename "$f")
    if [[ ! -e "$canonical_dir/$base" ]]; then
      rm -rf "$target_dir/$base"
    fi
  done
  # Copy canonical files to target
  cp -R "$canonical_dir"/. "$target_dir/"
  echo "Synced: $canonical_dir -> $target_dir"
}

# --- Symlink-based sync (legacy fallback) ---
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
    if [[ -n "$COPY_EXISTING" ]]; then
      if [[ -n "$DRY_RUN" ]]; then
        echo "[DRY RUN] Would copy $target_path into $canonical_dir and replace with symlink"
        return 0
      fi
      echo "Copying existing $target_path into $canonical_dir ..."
      mkdir -p "$canonical_dir"
      cp -Rn "$target_path"/. "$canonical_dir/" 2>/dev/null || true
      rm -rf "$target_path"
    else
      echo "Target $target_path already exists. Use --copy-existing to merge and replace." >&2
      return 2
    fi
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

# --- Dispatch ---
sync_target() {
  local canonical_dir="$1"
  local target_dir="$2"
  if [[ "$METHOD" == "copy" ]]; then
    copy_sync "$canonical_dir" "$target_dir"
  else
    create_symlink "$target_dir" "$canonical_dir"
  fi
}

run_for_ide() {
  local ide="$1"
  local ec=0

  if [[ "$TYPE" == "commands" || "$TYPE" == "all" ]]; then
    case "$ide" in
      cursor)      sync_target "$canonical_commands" "$cursor_commands" || ec=$? ;;
      windsurf)    sync_target "$canonical_commands" "$windsurf_commands" || ec=$? ;;
      kilocode)    sync_target "$canonical_commands" "$kilocode_commands" || ec=$? ;;
      antigravity) sync_target "$canonical_commands" "$antigravity_commands" || ec=$? ;;
    esac
    [[ $ec -eq 2 ]] && return 2
  fi

  if [[ "$TYPE" == "skills" || "$TYPE" == "all" ]]; then
    case "$ide" in
      cursor)      ;;  # Cursor reads .claude/skills directly; no sync needed
      windsurf)    sync_target "$canonical_skills" "$windsurf_skills" || ec=$? ;;
      kilocode)    sync_target "$canonical_skills" "$kilocode_skills" || ec=$? ;;
      antigravity) sync_target "$canonical_skills" "$antigravity_skills" || ec=$? ;;
    esac
    [[ $ec -eq 2 ]] && return 2
  fi

  return $ec
}

exit_code=0
for ide in "${IDE_LIST[@]}"; do
  ide="$(echo "$ide" | tr '[:upper:]' '[:lower:]' | xargs)"
  [[ -z "$ide" ]] && continue
  run_for_ide "$ide" || exit_code=$?
  [[ $exit_code -eq 2 ]] && break
done
exit $exit_code
