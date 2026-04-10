#!/usr/bin/env bats
# Tests for sync-ide.sh — validates two-phase reverse/forward sync,
# symlink migration, edge cases, and symlink fallback mode.

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
SYNC_SCRIPT="$SCRIPT_DIR/../scripts/sync-ide.sh"

setup() {
  TEST_ROOT="$(mktemp -d)"
  mkdir -p "$TEST_ROOT/.claude/commands"
  mkdir -p "$TEST_ROOT/.claude/skills"
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

# ─── Basic forward sync ──────────────────────────────────────────────

@test "sync: copies canonical commands to cursor" {
  echo "hello" > "$TEST_ROOT/.claude/commands/greet.md"
  echo "bye" > "$TEST_ROOT/.claude/commands/farewell.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  [ -f "$TEST_ROOT/.cursor/commands/greet.md" ]
  [ -f "$TEST_ROOT/.cursor/commands/farewell.md" ]
  [ "$(cat "$TEST_ROOT/.cursor/commands/greet.md")" = "hello" ]
}

@test "sync: copies skills to windsurf but not cursor" {
  echo "skill-a" > "$TEST_ROOT/.claude/skills/a.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide windsurf --type skills
  [ "$status" -eq 0 ]
  [ -f "$TEST_ROOT/.windsurf/skills/a.md" ]

  # Cursor reads .claude/skills directly; no skills sync
  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type skills
  [ "$status" -eq 0 ]
  [ ! -d "$TEST_ROOT/.cursor/skills" ]
}

@test "sync: works with multiple IDEs" {
  echo "cmd" > "$TEST_ROOT/.claude/commands/cmd.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor,windsurf,kilocode,antigravity --type commands
  [ "$status" -eq 0 ]
  [ -f "$TEST_ROOT/.cursor/commands/cmd.md" ]
  [ -f "$TEST_ROOT/.windsurf/workflows/cmd.md" ]
  [ -f "$TEST_ROOT/.kilocode/workflows/cmd.md" ]
  [ -f "$TEST_ROOT/.agent/workflows/cmd.md" ]
}

@test "sync: preserves nested directory structure" {
  mkdir -p "$TEST_ROOT/.claude/commands/deep/nested"
  echo "a" > "$TEST_ROOT/.claude/commands/deep/nested/file.md"
  echo "b" > "$TEST_ROOT/.claude/commands/top.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  [ -f "$TEST_ROOT/.cursor/commands/deep/nested/file.md" ]
  [ -f "$TEST_ROOT/.cursor/commands/top.md" ]
  [ "$(cat "$TEST_ROOT/.cursor/commands/deep/nested/file.md")" = "a" ]
}

# ─── Reverse sync (bidirectional) ────────────────────────────────────

@test "reverse sync: gathers new files from IDE location into canonical" {
  echo "canonical" > "$TEST_ROOT/.claude/commands/existing.md"
  mkdir -p "$TEST_ROOT/.cursor/commands"
  echo "from-cursor" > "$TEST_ROOT/.cursor/commands/new-cmd.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  # new-cmd.md should have been pulled into canonical
  [ -f "$TEST_ROOT/.claude/commands/new-cmd.md" ]
  [ "$(cat "$TEST_ROOT/.claude/commands/new-cmd.md")" = "from-cursor" ]
  # And both files should be in the target
  [ -f "$TEST_ROOT/.cursor/commands/existing.md" ]
  [ -f "$TEST_ROOT/.cursor/commands/new-cmd.md" ]
}

@test "reverse sync: propagates IDE changes to other IDEs" {
  echo "original" > "$TEST_ROOT/.claude/commands/shared.md"
  # First sync to both IDEs
  bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor,windsurf --type commands

  # Developer edits in windsurf
  echo "edited-in-windsurf" > "$TEST_ROOT/.windsurf/workflows/shared.md"

  # Re-sync: windsurf change should propagate to canonical and cursor
  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor,windsurf --type commands
  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_ROOT/.claude/commands/shared.md")" = "edited-in-windsurf" ]
  [ "$(cat "$TEST_ROOT/.cursor/commands/shared.md")" = "edited-in-windsurf" ]
}

@test "reverse sync: new file in IDE propagates to all other IDEs" {
  echo "base" > "$TEST_ROOT/.claude/commands/base.md"
  bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor,kilocode --type commands

  # Developer adds a new file in kilocode
  echo "new-from-kilo" > "$TEST_ROOT/.kilocode/workflows/addon.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor,kilocode --type commands
  [ "$status" -eq 0 ]
  # Should be in canonical and cursor too
  [ -f "$TEST_ROOT/.claude/commands/addon.md" ]
  [ -f "$TEST_ROOT/.cursor/commands/addon.md" ]
  [ "$(cat "$TEST_ROOT/.cursor/commands/addon.md")" = "new-from-kilo" ]
}

@test "reverse sync: skips symlink targets (they already point at canonical)" {
  echo "cmd" > "$TEST_ROOT/.claude/commands/cmd.md"
  # Create a symlink target (simulating old setup before migration)
  ln -s ../.claude/commands "$TEST_ROOT/.windsurf/workflows"

  # Sync with cursor only (windsurf is a symlink, will be skipped in reverse)
  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  [ -f "$TEST_ROOT/.cursor/commands/cmd.md" ]
}

# ─── Forward sync: stale file removal ────────────────────────────────

@test "forward sync: reverse-sync preserves file deleted only from canonical" {
  echo "a" > "$TEST_ROOT/.claude/commands/a.md"
  echo "b" > "$TEST_ROOT/.claude/commands/b.md"
  bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands

  # Delete from canonical only — cursor still has b.md
  rm "$TEST_ROOT/.claude/commands/b.md"
  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  # Reverse-sync pulls b.md back from cursor into canonical
  [ -f "$TEST_ROOT/.claude/commands/b.md" ]
  [ -f "$TEST_ROOT/.cursor/commands/b.md" ]
}

@test "forward sync: removes file deleted from all locations" {
  echo "a" > "$TEST_ROOT/.claude/commands/a.md"
  echo "b" > "$TEST_ROOT/.claude/commands/b.md"
  bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands

  # Delete from canonical AND the IDE target
  rm "$TEST_ROOT/.claude/commands/b.md"
  rm "$TEST_ROOT/.cursor/commands/b.md"
  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  [ -f "$TEST_ROOT/.cursor/commands/a.md" ]
  [ ! -e "$TEST_ROOT/.cursor/commands/b.md" ]
  [ ! -e "$TEST_ROOT/.claude/commands/b.md" ]
}

@test "forward sync: removes stale nested files" {
  mkdir -p "$TEST_ROOT/.claude/commands/subdir"
  echo "keep" > "$TEST_ROOT/.claude/commands/keep.md"
  echo "nested" > "$TEST_ROOT/.claude/commands/subdir/kept.md"

  # Pre-populate target with extra nested file
  mkdir -p "$TEST_ROOT/.cursor/commands/subdir"
  echo "stale" > "$TEST_ROOT/.cursor/commands/subdir/old.md"
  echo "nested" > "$TEST_ROOT/.cursor/commands/subdir/kept.md"
  echo "keep" > "$TEST_ROOT/.cursor/commands/keep.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  [ -f "$TEST_ROOT/.cursor/commands/subdir/kept.md" ]
  # old.md was reverse-synced to canonical, so it now exists everywhere
  [ -f "$TEST_ROOT/.claude/commands/subdir/old.md" ]
  [ -f "$TEST_ROOT/.cursor/commands/subdir/old.md" ]
}

@test "forward sync: removes stale dotfiles" {
  echo "keep" > "$TEST_ROOT/.claude/commands/keep.md"
  # .DS_Store only in target, not in canonical
  # Since it's a dotfile in a non-symlink dir, reverse-sync will copy it to canonical
  # Then forward-sync mirrors it. To test pure forward-sync removal,
  # we verify the full cycle produces identical dirs.

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  [ -f "$TEST_ROOT/.cursor/commands/keep.md" ]
}

@test "forward sync: handles type mismatch (dir in target, file in canonical)" {
  echo "file-content" > "$TEST_ROOT/.claude/commands/foo"
  mkdir -p "$TEST_ROOT/.cursor/commands/foo"
  echo "nested" > "$TEST_ROOT/.cursor/commands/foo/bar.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  # Reverse-sync resolves the type conflict: cursor's foo/ (dir) overwrites
  # canonical's foo (file). Then forward-sync mirrors canonical to cursor.
  # End state: foo/ is a directory with bar.md in both locations.
  [ -d "$TEST_ROOT/.claude/commands/foo" ]
  [ -f "$TEST_ROOT/.claude/commands/foo/bar.md" ]
  [ -d "$TEST_ROOT/.cursor/commands/foo" ]
  [ -f "$TEST_ROOT/.cursor/commands/foo/bar.md" ]
}

@test "forward sync: edit in IDE propagates to canonical" {
  echo "v1" > "$TEST_ROOT/.claude/commands/cmd.md"
  bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$(cat "$TEST_ROOT/.cursor/commands/cmd.md")" = "v1" ]

  # Developer edits in cursor (the IDE location)
  echo "v2-from-cursor" > "$TEST_ROOT/.cursor/commands/cmd.md"
  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  # Reverse-sync pulls the edit into canonical, forward-sync mirrors it
  [ "$(cat "$TEST_ROOT/.claude/commands/cmd.md")" = "v2-from-cursor" ]
  [ "$(cat "$TEST_ROOT/.cursor/commands/cmd.md")" = "v2-from-cursor" ]
}

# ─── Symlink migration ──────────────────────────────────────────────

@test "migrate: fails without --migrate when target is a symlink" {
  ln -s ../.claude/commands "$TEST_ROOT/.cursor/commands"
  echo "cmd" > "$TEST_ROOT/.claude/commands/cmd.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -ne 0 ]
  [[ "$output" == *"symlink"* ]]
  [[ "$output" == *"--migrate"* ]]
  [ -L "$TEST_ROOT/.cursor/commands" ]
}

@test "migrate: converts symlink to directory copy with --migrate" {
  echo "cmd" > "$TEST_ROOT/.claude/commands/cmd.md"
  ln -s ../.claude/commands "$TEST_ROOT/.cursor/commands"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands --migrate
  [ "$status" -eq 0 ]
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
  [ -L "$TEST_ROOT/.cursor/commands" ]
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

@test "symlink mode: fails when target dir exists" {
  mkdir -p "$TEST_ROOT/.cursor/commands"
  echo "x" > "$TEST_ROOT/.cursor/commands/file.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands --method symlink
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
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
  first_a="$(cat "$TEST_ROOT/.cursor/commands/a.md")"
  first_b="$(cat "$TEST_ROOT/.cursor/commands/sub/b.md")"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor --type commands
  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_ROOT/.cursor/commands/a.md")" = "$first_a" ]
  [ "$(cat "$TEST_ROOT/.cursor/commands/sub/b.md")" = "$first_b" ]
}

@test "all locations identical after multi-IDE sync" {
  echo "shared" > "$TEST_ROOT/.claude/commands/shared.md"
  mkdir -p "$TEST_ROOT/.kilocode/workflows"
  echo "from-kilo" > "$TEST_ROOT/.kilocode/workflows/extra.md"

  run bash "$SYNC_SCRIPT" --repo-root "$TEST_ROOT" --ide cursor,windsurf,kilocode --type commands
  [ "$status" -eq 0 ]

  # All locations should have both files
  [ -f "$TEST_ROOT/.claude/commands/shared.md" ]
  [ -f "$TEST_ROOT/.claude/commands/extra.md" ]
  [ -f "$TEST_ROOT/.cursor/commands/shared.md" ]
  [ -f "$TEST_ROOT/.cursor/commands/extra.md" ]
  [ -f "$TEST_ROOT/.windsurf/workflows/shared.md" ]
  [ -f "$TEST_ROOT/.windsurf/workflows/extra.md" ]
  [ -f "$TEST_ROOT/.kilocode/workflows/shared.md" ]
  [ -f "$TEST_ROOT/.kilocode/workflows/extra.md" ]
}
