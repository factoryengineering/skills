# Sync canonical .claude/ folders to IDE-specific locations.
# Default method: copy (recommended). Symlinks available via -Method symlink.
# Run from repository root. See sync.md for full workflow.
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
    [switch]$CopyExisting,
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
$targetsCommands = @{
    cursor      = '.cursor/commands'
    windsurf    = '.windsurf/workflows'
    kilocode    = '.kilocode/workflows'
    antigravity = '.agent/workflows'
}
# Cursor reads .claude/skills directly; no sync needed for cursor skills
$targetsSkills = @{
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

function Copy-SyncTarget {
    param(
        [string]$root,
        [string]$canonicalDir,
        [string]$targetDir,
        [bool]$copyExisting,
        [bool]$migrate,
        [bool]$dryRun
    )
    $canonicalFull = Join-Path $root $canonicalDir
    $targetFull = Join-Path $root $targetDir
    $parentDir = Split-Path -Parent $targetFull

    # Handle existing symlink (migration)
    if (Test-Path -LiteralPath $targetFull) {
        $item = Get-Item -LiteralPath $targetFull -Force
        $isLink = [bool]($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
        if ($isLink) {
            if ($migrate) {
                if ($dryRun) {
                    Write-Host "[DRY RUN] Would remove symlink $targetFull and create directory copy"
                    return 0
                }
                Write-Host "Migrating: removing symlink $targetFull ..."
                Remove-Item -LiteralPath $targetFull -Force
            } else {
                throw "$targetFull is a symlink. Use -Migrate to convert to a copy."
            }
        }
    }

    # Handle non-canonical files
    if ((Test-Path -LiteralPath $targetFull) -and (Test-Path -LiteralPath $canonicalFull)) {
        $targetItems = Get-ChildItem -LiteralPath $targetFull -Force -ErrorAction SilentlyContinue
        $hasConflicts = $false
        foreach ($f in $targetItems) {
            $canonicalMatch = Join-Path $canonicalFull $f.Name
            if (-not (Test-Path -LiteralPath $canonicalMatch)) {
                $hasConflicts = $true
                if ($copyExisting) {
                    if ($dryRun) {
                        Write-Host "[DRY RUN] Would merge $($f.FullName) -> $canonicalFull"
                    } else {
                        Copy-Item -LiteralPath $f.FullName -Destination $canonicalFull -Recurse -Force
                        Write-Host "Merged non-canonical file: $($f.Name) -> $canonicalDir/"
                    }
                } else {
                    Write-Host "Conflict: $targetDir/$($f.Name) is not in $canonicalDir"
                }
            }
        }
        if ($hasConflicts -and -not $copyExisting) {
            throw "Conflicts detected in $targetDir. Use -CopyExisting to merge files into $canonicalDir before syncing."
        }
    }

    if (-not (Test-Path -LiteralPath $canonicalFull)) {
        if ($dryRun) {
            Write-Host "[DRY RUN] Would create $canonicalDir (empty)"
        } else {
            New-Item -ItemType Directory -Path $canonicalFull -Force | Out-Null
        }
        Write-Host "Canonical folder $canonicalDir created (empty). Add files and re-run to sync."
        return 0
    }

    if ($dryRun) {
        Write-Host "[DRY RUN] Would sync $canonicalDir -> $targetDir"
        return 0
    }

    # Sync: mirror canonical to target (clean copy)
    if (-not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    if (Test-Path -LiteralPath $targetFull) {
        Remove-Item -LiteralPath $targetFull -Recurse -Force
    }
    Copy-Item -LiteralPath $canonicalFull -Destination $targetFull -Recurse -Force
    Write-Host "Synced: $canonicalDir -> $targetDir"
    return 0
}

function New-SymlinkForTarget {
    param(
        [string]$root,
        [string]$ideName,
        [string]$targetRelativePath,
        [string]$canonicalDir,
        [bool]$copyExisting,
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
                return 0
            }
            Write-Error "$targetPath is a symlink but not to $canonicalDir."
        }
        if ($item.PSIsContainer) {
            if ($copyExisting) {
                if ($dryRun) {
                    Write-Host "[DRY RUN] Would copy $targetPath into $canonicalDir and replace with symlink"
                    return 0
                }
                Write-Host "Copying existing $targetPath into $canonicalDir ..."
                if (-not (Test-Path -LiteralPath $canonicalFull)) {
                    New-Item -ItemType Directory -Path $canonicalFull -Force | Out-Null
                }
                Get-ChildItem -LiteralPath $targetPath -Force | Copy-Item -Destination $canonicalFull -Recurse -Force
                Remove-Item -LiteralPath $targetPath -Recurse -Force
            } else {
                Write-Error "Target $targetPath already exists. Use -CopyExisting to merge and replace."
            }
        } else {
            Write-Error "Target $targetPath exists as a file. Remove it first."
        }
    }

    if ($dryRun) {
        Write-Host "[DRY RUN] Would create symlink $targetPath -> $canonicalFull"
        return 0
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
        Write-Host "Symbolic link creation failed for $targetPath. Falling back to junction."
        $cmd = "mklink /J `"$targetPath`" `"$canonicalFull`""
        $null = cmd /c $cmd
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create junction: $targetPath -> $canonicalFull"
        }
        Write-Host "Created junction: $targetPath -> $canonicalFull"
    }
    return 0
}

# --- Main ---
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

if ($Method -eq 'symlink') {
    Write-Host "WARNING: Symlink mode selected. Known limitations:"
    Write-Host "  - Cursor has a documented bug where directory symlinks may not work"
    Write-Host "  - Windows requires Developer Mode or elevated privileges for symlinks"
    Write-Host "  - File-watching behavior varies across IDEs with symlinked directories"
    Write-Host "  - Git handling of symlinks is inconsistent across platforms"
    Write-Host "Consider using the default copy method instead (omit -Method or use -Method copy)."
    Write-Host ""
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

$exitCode = 0
foreach ($ide in $ideList) {
    try {
        if ($Type -eq 'commands' -or $Type -eq 'all') {
            $target = $targetsCommands[$ide]
            if ($Method -eq 'copy') {
                $null = Copy-SyncTarget -root $repoFull -canonicalDir $canonicalCommands -targetDir $target -copyExisting $CopyExisting.IsPresent -migrate $Migrate.IsPresent -dryRun $DryRun.IsPresent
            } else {
                $null = New-SymlinkForTarget -root $repoFull -ideName $ide -targetRelativePath $target -canonicalDir $canonicalCommands -copyExisting $CopyExisting.IsPresent -dryRun $DryRun.IsPresent -allowJunctionFallback (-not $NoJunctionFallback.IsPresent)
            }
        }
        if ($Type -eq 'skills' -or $Type -eq 'all') {
            $skillsTarget = $targetsSkills[$ide]
            if ($skillsTarget) {
                if ($Method -eq 'copy') {
                    $null = Copy-SyncTarget -root $repoFull -canonicalDir $canonicalSkills -targetDir $skillsTarget -copyExisting $CopyExisting.IsPresent -migrate $Migrate.IsPresent -dryRun $DryRun.IsPresent
                } else {
                    $null = New-SymlinkForTarget -root $repoFull -ideName $ide -targetRelativePath $skillsTarget -canonicalDir $canonicalSkills -copyExisting $CopyExisting.IsPresent -dryRun $DryRun.IsPresent -allowJunctionFallback (-not $NoJunctionFallback.IsPresent)
                }
            }
        }
    } catch {
        Write-Host $_.Exception.Message
        $exitCode = 2
        break
    }
}
exit $exitCode
