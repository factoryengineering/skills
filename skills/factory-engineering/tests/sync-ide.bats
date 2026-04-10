#!/usr/bin/env bats
# Tests for sync-ide.sh — validates copy-based sync, migration, conflict
# resolution, and edge cases identified during code review.

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
SYNC_SCRIPT="$SCRIPT_DIR/../scripts/sync-ide.sh"

setup() {
  TEST_ROOT="$(mktemp -d)"
  # Minimal canonical structure
  mkdir -p "$TEST_ROOT/.claude/commands"
  mkdir -p "$TEST_ROOT/.claude/skills"
  # IDE marker directories so --detect finds them
  mkdir -p "$TEST_ROOT/.cursor"
  mkdir -p "$TEST_ROOT/.windsurf"
  mkdir -p "$TEST_ROOT/.kilocode"
  mkdir -p "$TEST_ROOT/.agent"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

# ─── Detection ────────────────────────────────────────────────────────

@test "detect: finds all IDE directories" {
  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --detect
  [ "$status" -eq 0 ]
  [[ "$output" == *"cursor"* ]]
  [[ "$output" == *"windsurf"* ]]
  [[ "$output" == *"kilocode"* ]]
  [[ "$output" == *"antigravity"* ]]
}

@test "detect: reports none when no IDE dirs exist" {
  rm -rf "$TEST_ROOT/.cursor" "$TEST_ROOT/.windsurf" "$TEST_ROOT/.kilocode" "$TEST_ROOT/.agent"
  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --detect
  [ "$status" -eq 0 ]
  [[ "$output" == *"No IDE directories"* ]]
}

# ─── Basic copy sync ─────────────────────────────────────────────────

@test "copy sync: creates target directory with canonical contents" {
  echo "hello" > "$TEST_ROOT/.claude/commands/greet.md"
  echo "world" > "$TEST_ROOT/.claude/commands/farewell.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  [ -f "$TEST_ROOT/.cursor/commands/greet.md" ]
  [ -f "$TEST_ROOT/.cursor/commands/farewell.md" ]
  [ "$(cat "$TEST_ROOT/.cursor/commands/greet.md")" = "hello" ]
}

@test "copy sync: syncs skills to windsurf but not cursor" {
  echo "skill-a" > "$TEST_ROOT/.claude/skills/a.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide windsurf --type skills
  [ "$status" -eq 0 ]
  [ -f "$TEST_ROOT/.windsurf/skills/a.md" ]

  # Cursor should NOT get a skills copy
  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type skills
  [ "$status" -eq 0 ]
  [ ! -d "$TEST_ROOT/.cursor/skills" ]
}

@test "copy sync: works with multiple IDEs" {
  echo "cmd" > "$TEST_ROOT/.claude/commands/cmd.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor,windsurf,kilocode,antigravity --type commands
  [ "$status" -eq 0 ]
  [ -f "$TEST_ROOT/.cursor/commands/cmd.md" ]
  [ -f "$TEST_ROOT/.windsurf/workflows/cmd.md" ]
  [ -f "$TEST_ROOT/.kilocode/workflows/cmd.md" ]
  [ -f "$TEST_ROOT/.agent/workflows/cmd.md" ]
}

@test "copy sync: creates empty canonical dir when missing" {
  rm -rf "$TEST_ROOT/.claude/commands"
  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  [ -d "$TEST_ROOT/.claude/commands" ]
  [[ "$output" == *"created (empty)"* ]]
}

# ─── Clean mirror: nested files and dotfiles ─────────────────────────

@test "clean sync: removes stale nested files within a shared directory" {
  # subdir exists in both canonical and target, but target has an extra file inside it.
  # Conflict detection only compares top-level names, so subdir passes.
  # The rm+cp mirror should remove the stale nested file.
  mkdir -p "$TEST_ROOT/.claude/commands/subdir"
  echo "keep" > "$TEST_ROOT/.claude/commands/keep.md"
  echo "canonical" > "$TEST_ROOT/.claude/commands/subdir/kept.md"

  mkdir -p "$TEST_ROOT/.cursor/commands/subdir"
  echo "keep" > "$TEST_ROOT/.cursor/commands/keep.md"
  echo "canonical" > "$TEST_ROOT/.cursor/commands/subdir/kept.md"
  echo "stale" > "$TEST_ROOT/.cursor/commands/subdir/old.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  [ -f "$TEST_ROOT/.cursor/commands/keep.md" ]
  [ -f "$TEST_ROOT/.cursor/commands/subdir/kept.md" ]
  [ ! -e "$TEST_ROOT/.cursor/commands/subdir/old.md" ]
}

@test "clean sync: removes stale dotfiles from target" {
  echo "keep" > "$TEST_ROOT/.claude/commands/keep.md"
  mkdir -p "$TEST_ROOT/.cursor/commands"
  echo "ds" > "$TEST_ROOT/.cursor/commands/.DS_Store"
  echo "keep" > "$TEST_ROOT/.cursor/commands/keep.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  [ -f "$TEST_ROOT/.cursor/commands/keep.md" ]
  [ ! -e "$TEST_ROOT/.cursor/commands/.DS_Store" ]
}

@test "clean sync: handles type mismatch (dir in target, file in canonical)" {
  echo "file-content" > "$TEST_ROOT/.claude/commands/foo"
  mkdir -p "$TEST_ROOT/.cursor/commands/foo"
  echo "nested" > "$TEST_ROOT/.cursor/commands/foo/bar.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  [ -f "$TEST_ROOT/.cursor/commands/foo" ]
  [ ! -d "$TEST_ROOT/.cursor/commands/foo" ]
  [ "$(cat "$TEST_ROOT/.cursor/commands/foo")" = "file-content" ]
}

@test "clean sync: handles type mismatch (file in target, dir in canonical)" {
  mkdir -p "$TEST_ROOT/.claude/commands/subdir"
  echo "nested" > "$TEST_ROOT/.claude/commands/subdir/file.md"
  mkdir -p "$TEST_ROOT/.cursor/commands"
  echo "was-a-file" > "$TEST_ROOT/.cursor/commands/subdir"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  [ -d "$TEST_ROOT/.cursor/commands/subdir" ]
  [ -f "$TEST_ROOT/.cursor/commands/subdir/file.md" ]
}

@test "clean sync: preserves nested directory structure from canonical" {
  mkdir -p "$TEST_ROOT/.claude/commands/deep/nested"
  echo "a" > "$TEST_ROOT/.claude/commands/deep/nested/file.md"
  echo "b" > "$TEST_ROOT/.claude/commands/top.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  [ -f "$TEST_ROOT/.cursor/commands/deep/nested/file.md" ]
  [ -f "$TEST_ROOT/.cursor/commands/top.md" ]
  [ "$(cat "$TEST_ROOT/.cursor/commands/deep/nested/file.md")" = "a" ]
}

# ─── Symlink migration ──────────────────────────────────────────────

@test "migrate: fails without --migrate when target is a symlink" {
  ln -s ../.claude/commands "$TEST_ROOT/.cursor/commands"
  echo "cmd" > "$TEST_ROOT/.claude/commands/cmd.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -ne 0 ]
  [[ "$output" == *"symlink"* ]]
  [[ "$output" == *"--migrate"* ]]
  # Target should still be a symlink (unchanged)
  [ -L "$TEST_ROOT/.cursor/commands" ]
}

@test "migrate: converts symlink to directory copy with --migrate" {
  echo "cmd" > "$TEST_ROOT/.claude/commands/cmd.md"
  ln -s ../.claude/commands "$TEST_ROOT/.cursor/commands"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands --migrate
  [ "$status" -eq 0 ]
  # Should now be a real directory, not a symlink
  [ -d "$TEST_ROOT/.cursor/commands" ]
  [ ! -L "$TEST_ROOT/.cursor/commands" ]
  [ -f "$TEST_ROOT/.cursor/commands/cmd.md" ]
  [ "$(cat "$TEST_ROOT/.cursor/commands/cmd.md")" = "cmd" ]
}

@test "migrate: dry-run does not remove the symlink" {
  echo "cmd" > "$TEST_ROOT/.claude/commands/cmd.md"
  ln -s ../.claude/commands "$TEST_ROOT/.cursor/commands"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands --migrate --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
  # Symlink should still exist
  [ -L "$TEST_ROOT/.cursor/commands" ]
}

# ─── Conflict resolution ────────────────────────────────────────────

@test "conflict: fails when target has non-canonical files without --copy-existing" {
  echo "shared" > "$TEST_ROOT/.claude/commands/shared.md"
  mkdir -p "$TEST_ROOT/.cursor/commands"
  echo "shared" > "$TEST_ROOT/.cursor/commands/shared.md"
  echo "extra" > "$TEST_ROOT/.cursor/commands/only-here.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -ne 0 ]
  [[ "$output" == *"Conflict"* ]]
  [[ "$output" == *"only-here.md"* ]]
}

@test "conflict: --copy-existing merges non-canonical files into canonical then syncs" {
  echo "shared" > "$TEST_ROOT/.claude/commands/shared.md"
  mkdir -p "$TEST_ROOT/.cursor/commands"
  echo "shared" > "$TEST_ROOT/.cursor/commands/shared.md"
  echo "extra" > "$TEST_ROOT/.cursor/commands/only-here.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands --copy-existing
  [ "$status" -eq 0 ]
  # Non-canonical file should now be in canonical
  [ -f "$TEST_ROOT/.claude/commands/only-here.md" ]
  [ "$(cat "$TEST_ROOT/.claude/commands/only-here.md")" = "extra" ]
  # And synced back to target
  [ -f "$TEST_ROOT/.cursor/commands/only-here.md" ]
  [ -f "$TEST_ROOT/.cursor/commands/shared.md" ]
}

@test "conflict: no error when target has only canonical files" {
  echo "a" > "$TEST_ROOT/.claude/commands/a.md"
  mkdir -p "$TEST_ROOT/.cursor/commands"
  echo "old-a" > "$TEST_ROOT/.cursor/commands/a.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  # Should be overwritten with canonical content
  [ "$(cat "$TEST_ROOT/.cursor/commands/a.md")" = "a" ]
}

# ─── Dry run ─────────────────────────────────────────────────────────

@test "dry-run: does not create target directory" {
  echo "cmd" > "$TEST_ROOT/.claude/commands/cmd.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
  [ ! -d "$TEST_ROOT/.cursor/commands" ]
}

@test "dry-run: does not modify existing target" {
  echo "new" > "$TEST_ROOT/.claude/commands/cmd.md"
  mkdir -p "$TEST_ROOT/.cursor/commands"
  echo "old" > "$TEST_ROOT/.cursor/commands/cmd.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands --dry-run
  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_ROOT/.cursor/commands/cmd.md")" = "old" ]
}

# ─── Symlink fallback mode ───────────────────────────────────────────

@test "symlink mode: prints warning" {
  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands --method symlink
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING"* ]]
  [[ "$output" == *"Symlink mode"* ]]
}

@test "symlink mode: creates working symlink" {
  echo "cmd" > "$TEST_ROOT/.claude/commands/cmd.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands --method symlink
  [ "$status" -eq 0 ]
  [ -L "$TEST_ROOT/.cursor/commands" ]
  [ -f "$TEST_ROOT/.cursor/commands/cmd.md" ]
}

@test "symlink mode: idempotent when symlink already exists" {
  echo "cmd" > "$TEST_ROOT/.claude/commands/cmd.md"
  mkdir -p "$TEST_ROOT/.cursor"
  ln -s ../.claude/commands "$TEST_ROOT/.cursor/commands"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands --method symlink
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already a symlink"* ]]
}

@test "symlink mode: fails when target dir exists without --copy-existing" {
  mkdir -p "$TEST_ROOT/.cursor/commands"
  echo "x" > "$TEST_ROOT/.cursor/commands/file.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands --method symlink
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
}

@test "symlink mode: --copy-existing merges then creates symlink" {
  echo "extra" > "$TEST_ROOT/.claude/commands/existing.md"
  mkdir -p "$TEST_ROOT/.cursor/commands"
  echo "local" > "$TEST_ROOT/.cursor/commands/local-only.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands --method symlink --copy-existing
  [ "$status" -eq 0 ]
  [ -L "$TEST_ROOT/.cursor/commands" ]
  # local-only.md should have been copied to canonical
  [ -f "$TEST_ROOT/.claude/commands/local-only.md" ]
}

# ─── Validation ──────────────────────────────────────────────────────

@test "rejects unknown IDE" {
  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide vscode
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown IDE"* ]]
}

@test "rejects unknown --type" {
  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --type widgets --ide cursor
  [ "$status" -ne 0 ]
}

@test "rejects unknown --method" {
  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --method rsync --ide cursor
  [ "$status" -ne 0 ]
}

@test "requires --ide or --detect" {
  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"specify --ide"* ]]
}

# ─── Idempotency ─────────────────────────────────────────────────────

@test "running sync twice produces identical results" {
  echo "a" > "$TEST_ROOT/.claude/commands/a.md"
  mkdir -p "$TEST_ROOT/.claude/commands/sub"
  echo "b" > "$TEST_ROOT/.claude/commands/sub/b.md"

  bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  # Capture state after first run
  first_a="$(cat "$TEST_ROOT/.cursor/commands/a.md")"
  first_b="$(cat "$TEST_ROOT/.cursor/commands/sub/b.md")"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_ROOT/.cursor/commands/a.md")" = "$first_a" ]
  [ "$(cat "$TEST_ROOT/.cursor/commands/sub/b.md")" = "$first_b" ]
}

@test "sync reflects updated canonical content" {
  echo "v1" > "$TEST_ROOT/.claude/commands/cmd.md"
  bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$(cat "$TEST_ROOT/.cursor/commands/cmd.md")" = "v1" ]

  echo "v2" > "$TEST_ROOT/.claude/commands/cmd.md"
  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_ROOT/.cursor/commands/cmd.md")" = "v2" ]
}

@test "conflict: detects file deleted from canonical but still in target" {
  echo "a" > "$TEST_ROOT/.claude/commands/a.md"
  echo "b" > "$TEST_ROOT/.claude/commands/b.md"
  bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ -f "$TEST_ROOT/.cursor/commands/b.md" ]

  # Delete from canonical only — target still has b.md
  rm "$TEST_ROOT/.claude/commands/b.md"
  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -ne 0 ]
  [[ "$output" == *"Conflict"* ]]
  [[ "$output" == *"b.md"* ]]
}

@test "sync reflects deleted canonical file with --copy-existing" {
  echo "a" > "$TEST_ROOT/.claude/commands/a.md"
  echo "b" > "$TEST_ROOT/.claude/commands/b.md"
  bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands

  rm "$TEST_ROOT/.claude/commands/b.md"
  # --copy-existing merges b.md back to canonical, then clean sync mirrors canonical
  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands --copy-existing
  [ "$status" -eq 0 ]
  [ -f "$TEST_ROOT/.cursor/commands/a.md" ]
  # b.md is merged back to canonical, so it exists in both places
  [ -f "$TEST_ROOT/.claude/commands/b.md" ]
  [ -f "$TEST_ROOT/.cursor/commands/b.md" ]
}
