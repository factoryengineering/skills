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
# Usage:
#   .\Sync-Ide.ps1 -Detect
#   .\Sync-Ide.ps1 -Ide "cursor,windsurf"
#   .\Sync-Ide.ps1 -Ide cursor -Method symlink
#   .\Sync-Ide.ps1 -Migrate -Ide cursor
#   .\Sync-Ide.ps1 -DryRun -Ide "cursor,windsurf"
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (Get-Location).Path,
    [Parameter(Mandatory = $false)]
    [ValidateSet('commands', 'skills', 'all')]
    [string]$Type = 'all',
    [Parameter(Mandatory = $false)]
    [ValidateSet('copy', 'symlink')]
    [string]$Method = 'copy',
    [Parameter(Mandatory = $false)]
    [switch]$Detect,
    [Parameter(Mandatory = $false)]
    [string[]]$Ide,
    [Parameter(Mandatory = $false)]
    [switch]$Migrate,
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,
    [Parameter(Mandatory = $false)]
    [switch]$NoJunctionFallback
)

$ErrorActionPreference = 'Stop'

$canonicalCommands = '.claude/commands'
$canonicalSkills = '.claude/skills'
$commandsMap = @{
    cursor      = '.cursor/commands'
    windsurf    = '.windsurf/workflows'
    kilocode    = '.kilocode/workflows'
    antigravity = '.agent/workflows'
}
# Cursor reads .claude/skills directly; no sync needed for cursor skills
$skillsMap = @{
    windsurf    = '.windsurf/skills'
    kilocode    = '.kilocode/skills'
    antigravity = '.agent/skills'
}

function Get-DetectedIdes {
    param([string]$root)
    $detected = @()
    if (Test-Path -LiteralPath (Join-Path $root '.cursor')) { $detected += 'cursor' }
    if (Test-Path -LiteralPath (Join-Path $root '.windsurf')) { $detected += 'windsurf' }
    if (Test-Path -LiteralPath (Join-Path $root '.kilocode')) { $detected += 'kilocode' }
    if (Test-Path -LiteralPath (Join-Path $root '.agent')) { $detected += 'antigravity' }
    return $detected
}

function Remove-SymlinkIfNeeded {
    param([string]$path, [bool]$migrate, [bool]$dryRun)
    if (-not (Test-Path -LiteralPath $path)) { return }
    $item = Get-Item -LiteralPath $path -Force
    $isLink = [bool]($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
    if (-not $isLink) { return }
    if ($migrate) {
        if ($dryRun) {
            Write-Host "[DRY RUN] Would remove symlink $path"
        } else {
            Remove-Item -LiteralPath $path -Force
            Write-Host "Migrated: removed symlink $path"
        }
    } else {
        throw "$path is a symlink. Use -Migrate to convert to a copy."
    }
}

function Invoke-ReverseSync {
    param([string]$src, [string]$dest, [bool]$dryRun)
    if (-not (Test-Path -LiteralPath $src)) { return }
    # Skip if src is a symlink (it points at canonical already)
    $srcItem = Get-Item -LiteralPath $src -Force
    if ([bool]($srcItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) { return }
    if (-not (Test-Path -LiteralPath $dest)) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
    }
    if ($dryRun) {
        Write-Host "[DRY RUN] Would reverse-sync $src -> $dest"
        return
    }
    Get-ChildItem -LiteralPath $src -Force | Copy-Item -Destination $dest -Recurse -Force
    Write-Host "Reverse-synced: $src -> $dest"
}

function Invoke-ForwardSync {
    param([string]$src, [string]$dest, [bool]$dryRun)
    if (-not (Test-Path -LiteralPath $src)) { return }
    if ($dryRun) {
        Write-Host "[DRY RUN] Would forward-sync $src -> $dest"
        return
    }
    $parentDir = Split-Path -Parent $dest
    if (-not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    if (Test-Path -LiteralPath $dest) {
        Remove-Item -LiteralPath $dest -Recurse -Force
    }
    Copy-Item -LiteralPath $src -Destination $dest -Recurse -Force
    Write-Host "Forward-synced: $src -> $dest"
}

function New-SymlinkForTarget {
    param(
        [string]$root,
        [string]$targetRelativePath,
        [string]$canonicalDir,
        [bool]$dryRun,
        [bool]$allowJunctionFallback
    )
    $targetPath = Join-Path $root $targetRelativePath
    $parentDir = Split-Path -Parent $targetPath
    $canonicalFull = Join-Path $root $canonicalDir

    if (Test-Path -LiteralPath $targetPath) {
        $item = Get-Item -LiteralPath $targetPath -Force
        if ([bool]($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            $linkTarget = $item.Target
            if ($linkTarget -and ($linkTarget -match "\.claude[\\/](commands|skills)$")) {
                Write-Host "Already a symlink: $targetPath"
                return
            }
            throw "$targetPath is a symlink but not to $canonicalDir."
        }
        if ($item.PSIsContainer) {
            throw "$targetPath already exists as a directory. Remove it or use copy mode."
        } else {
            throw "$targetPath exists as a file. Remove it first."
        }
    }

    if ($dryRun) {
        Write-Host "[DRY RUN] Would create symlink $targetPath -> $canonicalFull"
        return
    }

    if (-not (Test-Path -LiteralPath $canonicalFull)) {
        New-Item -ItemType Directory -Path $canonicalFull -Force | Out-Null
    }
    $canonicalFull = (Resolve-Path -LiteralPath $canonicalFull).Path

    if (-not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    try {
        New-Item -ItemType SymbolicLink -Path $targetPath -Target $canonicalFull -Force | Out-Null
        Write-Host "Created symbolic link: $targetPath -> $canonicalFull"
    } catch {
        if (-not $allowJunctionFallback) { throw }
        Write-Host "Symbolic link failed for $targetPath. Falling back to junction."
        $cmd = "mklink /J `"$targetPath`" `"$canonicalFull`""
        $null = cmd /c $cmd
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create junction: $targetPath -> $canonicalFull"
        }
        Write-Host "Created junction: $targetPath -> $canonicalFull"
    }
}

# ─── Main ─────────────────────────────────────────────────────────────

$repoFull = (Resolve-Path -LiteralPath $RepoRoot).Path
Set-Location $repoFull

if ($Detect) {
    $detected = Get-DetectedIdes -root $repoFull
    if ($detected.Count -eq 0) {
        Write-Host "No IDE directories (.cursor, .windsurf, .kilocode, .agent) found in $repoFull"
    } else {
        $detected | ForEach-Object { Write-Host $_ }
    }
    exit 0
}

if (-not $Ide) {
    Write-Error "Specify -Ide cursor,windsurf,kilocode,antigravity or run with -Detect first."
}

$ideList = @(
    $Ide |
        ForEach-Object { $_ -split '[,;\s]+' } |
        ForEach-Object { $_.Trim().ToLowerInvariant() } |
        Where-Object { $_ }
)
$validIdes = @('cursor', 'windsurf', 'kilocode', 'antigravity')
foreach ($ide in $ideList) {
    if ($ide -notin $validIdes) {
        Write-Error "Unknown IDE: $ide. Use cursor, windsurf, kilocode, antigravity."
    }
}

# ── Symlink mode ──────────────────────────────────────────────────────

if ($Method -eq 'symlink') {
    Write-Host "WARNING: Symlink mode selected. Known limitations:"
    Write-Host "  - Cursor has a documented bug where directory symlinks may not work"
    Write-Host "  - Windows requires Developer Mode or elevated privileges for symlinks"
    Write-Host "  - File-watching behavior varies across IDEs with symlinked directories"
    Write-Host "  - Git handling of symlinks is inconsistent across platforms"
    Write-Host "Consider using the default copy method instead."
    Write-Host ""

    $exitCode = 0
    foreach ($ide in $ideList) {
        try {
            if ($Type -eq 'commands' -or $Type -eq 'all') {
                $target = $commandsMap[$ide]
                if ($target) {
                    New-SymlinkForTarget -root $repoFull -targetRelativePath $target -canonicalDir $canonicalCommands -dryRun $DryRun.IsPresent -allowJunctionFallback (-not $NoJunctionFallback.IsPresent)
                }
            }
            if ($Type -eq 'skills' -or $Type -eq 'all') {
                $target = $skillsMap[$ide]
                if ($target) {
                    New-SymlinkForTarget -root $repoFull -targetRelativePath $target -canonicalDir $canonicalSkills -dryRun $DryRun.IsPresent -allowJunctionFallback (-not $NoJunctionFallback.IsPresent)
                }
            }
        } catch {
            Write-Host $_.Exception.Message
            $exitCode = 1
            break
        }
    }
    exit $exitCode
}

# ── Copy mode: two-phase sync ────────────────────────────────────────

# Collect target dirs
$commandsTargets = @()
$skillsTargets = @()
foreach ($ide in $ideList) {
    if ($Type -eq 'commands' -or $Type -eq 'all') {
        $t = $commandsMap[$ide]
        if ($t) { $commandsTargets += (Join-Path $repoFull $t) }
    }
    if ($Type -eq 'skills' -or $Type -eq 'all') {
        $t = $skillsMap[$ide]
        if ($t) { $skillsTargets += (Join-Path $repoFull $t) }
    }
}

$canonicalCommandsFull = Join-Path $repoFull $canonicalCommands
$canonicalSkillsFull = Join-Path $repoFull $canonicalSkills

# Handle symlink migration
try {
    foreach ($t in ($commandsTargets + $skillsTargets)) {
        Remove-SymlinkIfNeeded -path $t -migrate $Migrate.IsPresent -dryRun $DryRun.IsPresent
    }
} catch {
    Write-Host $_.Exception.Message
    exit 1
}

# Ensure canonical dirs exist
if (-not (Test-Path -LiteralPath $canonicalCommandsFull)) {
    New-Item -ItemType Directory -Path $canonicalCommandsFull -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $canonicalSkillsFull)) {
    New-Item -ItemType Directory -Path $canonicalSkillsFull -Force | Out-Null
}

# Phase 1: Reverse-sync
foreach ($t in $commandsTargets) {
    Invoke-ReverseSync -src $t -dest $canonicalCommandsFull -dryRun $DryRun.IsPresent
}
foreach ($t in $skillsTargets) {
    Invoke-ReverseSync -src $t -dest $canonicalSkillsFull -dryRun $DryRun.IsPresent
}

# Phase 2: Forward-sync
foreach ($t in $commandsTargets) {
    Invoke-ForwardSync -src $canonicalCommandsFull -dest $t -dryRun $DryRun.IsPresent
}
foreach ($t in $skillsTargets) {
    Invoke-ForwardSync -src $canonicalSkillsFull -dest $t -dryRun $DryRun.IsPresent
}
