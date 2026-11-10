<#
.SYNOPSIS
  Publishes this repo's shared Claude Code items to the team share (\\sic2tfs1\Claude\Prod), with a
  backup of everything it replaces and a rollback.

.DESCRIPTION
  This is the maintainer's step. Team members then run create-symlinks.bat, which links their
  ~/.claude (and every other Claude Code account on their machine) to what is published here.

  What it publishes (only files git tracks or would track, so ignored junk never goes up):
    Into the PROD folder (-Target):
      skills/<x>, agents/<x>, agent-notes/<x>, agent-tasks/<x>, commands/<x>, hooks/<x>,
      output-styles/<x>, rules/<x>, memory/<x>, mods/<x>, claude-plugin-marketplace, CLAUDE.md,
      plus what the link step needs: install.ps1, retired.txt, settings.template.json.
    Into the share root (-ShareRoot):
      create-symlinks.bat, and docs/share/README.md as README.md.

  How:
    1. Checks first, before anything changes: the repo has no uncommitted changes (unless -AllowDirty),
       the generated developer agents are current, rules/shaw-estate.md still holds the <DB_PASSWORD>
       placeholder and no real password, and the share can be read.
    2. Every item is copied to a staging folder on the share first.
    3. Then, one item at a time, the old item is moved into the backup folder and the staged one is
       moved into its place. On the same share a move is a rename, so each item is missing for only a
       moment. If the old item can't be moved (someone has a file in it open), it is left as it is and
       reported; run again later.
    4. Items listed in retired.txt are moved into the backup folder.
    5. Items on the share that this repo doesn't hold are left alone and listed.
  Every change is written to the backup folder's manifest.json as it happens.

.EXAMPLE
  .\publish-to-prod.ps1 -WhatIf                                     # preview; changes nothing
  .\publish-to-prod.ps1                                             # publish to PROD
  .\publish-to-prod.ps1 -Target \\sic2tfs1\Claude\Dev -ShareRoot "" # publish to Dev only (no root files)
  .\publish-to-prod.ps1 -Rollback "\\sic2tfs1\Claude\Backups\publish-20261110-160000"
#>
[CmdletBinding()]
param(
    [switch]$WhatIf,
    [string]$Rollback = "",
    [string]$Target = "\\sic2tfs1\Claude\Prod",
    [string]$ShareRoot = "\\sic2tfs1\Claude",
    [string]$BackupRoot = "\\sic2tfs1\Claude\Backups",
    [switch]$AllowDirty
)

$ErrorActionPreference = "Stop"
$Repo = $PSScriptRoot
$Target = $Target.TrimEnd('\')
$ShareRoot = $ShareRoot.TrimEnd('\')
$Merged = "skills", "agents", "agent-notes", "agent-tasks", "commands", "hooks", "output-styles", "rules", "memory", "mods"
$Utf8 = New-Object System.Text.UTF8Encoding($false)

function Say([string]$Tag, [string]$Text, [string]$Color = "Gray") {
    if ($WhatIf) { $Tag = "WHATIF $Tag" }
    Write-Host ("[{0}] {1}" -f $Tag, $Text) -ForegroundColor $Color
}

function Save-Manifest {
    if ($WhatIf) { return }
    $mf = Join-Path $script:BackupDir "manifest.json"
    [IO.File]::WriteAllText("$mf.tmp", ($script:Manifest | ConvertTo-Json -Depth 6), $Utf8)
    Move-Item -LiteralPath "$mf.tmp" -Destination $mf -Force
}

function Add-Action([hashtable]$A) { $script:Manifest.actions += [pscustomobject]$A; Save-Manifest }

function Get-Key([string]$Dest) {
    # A short, unique name for a destination, used for its place in the backup folder.
    foreach ($root in @($Target, $ShareRoot) | Where-Object { $_ }) {
        if ($Dest.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) {
            return (Split-Path $root -Leaf) + '\' + $Dest.Substring($root.Length + 1)
        }
    }
    throw "Refusing to touch a path outside $Target and $ShareRoot : $Dest"
}

function Move-Safe([string]$From, [string]$To) {
    $p = Split-Path $To -Parent
    if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    Move-Item -LiteralPath $From -Destination $To -ErrorAction Stop
}

# ---------------------------------------------------------------- rollback

function Invoke-Rollback([string]$Dir) {
    $Dir = $Dir.TrimEnd('\')
    $mf = Join-Path $Dir "manifest.json"
    if (-not (Test-Path -LiteralPath $mf)) { throw "No manifest.json in $Dir" }
    $m = [IO.File]::ReadAllText($mf, $Utf8) | ConvertFrom-Json
    $save = Join-Path $Dir ("before-rollback-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    Write-Host "Rolling back the publish of $($m.created) to $($m.target)`n"
    $acts = @($m.actions); [array]::Reverse($acts)
    $problems = 0
    foreach ($a in $acts) {
        try {
            if ($a.action -eq 'mkdir') {
                # Removed only if empty; anything someone put there since is kept.
                if ((Test-Path -LiteralPath $a.dest) -and -not (Get-ChildItem -LiteralPath $a.dest -Force)) {
                    if (-not $WhatIf) { Remove-Item -LiteralPath $a.dest -Force }
                    Say "REMOVE" "$($a.dest)\ (created by the publish)" Yellow
                }
                continue
            }
            if ($a.action -in 'replace', 'create' -and (Test-Path -LiteralPath $a.dest)) {
                if (-not $WhatIf) { Move-Safe $a.dest (Join-Path $save $a.key) }   # keep what is there now
            }
            if ($a.action -in 'replace', 'delete') {
                if (-not $WhatIf) { Move-Safe (Join-Path $Dir "files\$($a.key)") $a.dest }
                Say "RESTORE" $a.dest Green
            }
            else { Say "REMOVE" "$($a.dest) (added by the publish)" Yellow }
        }
        catch { $problems++; Write-Host "[ERROR]  $($a.dest): $($_.Exception.Message)" -ForegroundColor Red }
    }
    if (-not $WhatIf -and (Test-Path -LiteralPath $save)) { Write-Host "`n[NOTE]   What was there before this rollback is in $save" -ForegroundColor Cyan }
    if ($problems) { Write-Host "`n$problems item(s) could not be rolled back (see above); fix the cause and run the rollback again." -ForegroundColor Red; exit 1 }
    Write-Host "`nRollback done. Team members pick it up the next time Claude Code starts."
}

if ($Rollback) { Invoke-Rollback $Rollback; return }

# ---------------------------------------------------------------- checks (nothing changed yet)

$stop = @()
$files = @(& git -C $Repo ls-files --cached --others --exclude-standard 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $files) { throw "git is needed to publish (it decides which files go up)." }
$files = @($files | Where-Object { Test-Path -LiteralPath (Join-Path $Repo $_) -PathType Leaf })

$dirty = @(& git -C $Repo status --porcelain 2>$null)
if ($dirty.Count -and -not $AllowDirty) { $stop += "The repo has uncommitted changes. Commit them first (or pass -AllowDirty)." }

$global:LASTEXITCODE = 0
& (Join-Path $Repo "scripts\build-developer-agents.ps1") -Check *> $null
if ($LASTEXITCODE -ne 0) { $stop += "Generated developer agents are stale. Run scripts\build-developer-agents.ps1 and commit." }

$estate = [IO.File]::ReadAllText((Join-Path $Repo "rules\shaw-estate.md"), $Utf8)
if (-not $estate.Contains('<DB_PASSWORD>') -or [regex]::IsMatch($estate, 'Password=(?!<DB_PASSWORD>)[^;\s]+;')) {
    $stop += "rules\shaw-estate.md must hold the <DB_PASSWORD> placeholder and no real password."
}

try { $null = Get-ChildItem -LiteralPath $Target -Force -ErrorAction Stop } catch { $stop += "Can't read $Target. Connect to the network (or VPN)." }
if ($ShareRoot) { try { $null = Get-ChildItem -LiteralPath $ShareRoot -Force -ErrorAction Stop } catch { $stop += "Can't read $ShareRoot." } }

if ($stop.Count) {
    Write-Host "[STOP]   Nothing was changed:" -ForegroundColor Red
    $stop | ForEach-Object { Write-Host "         $_" -ForegroundColor Red }
    exit 2
}

# ---------------------------------------------------------------- what goes where

# Each item: the repo files that make it up, and where it lands.
$items = New-Object System.Collections.ArrayList
function Add-Item([string]$RepoRel, [string]$Dest) {
    $prefix = ($RepoRel -replace '\\', '/')
    $fs = @($files | Where-Object { $_ -eq $prefix -or $_.StartsWith("$prefix/") })
    if ($fs.Count) { [void]$items.Add([pscustomobject]@{ repoRel = $prefix; dest = $Dest; files = $fs }) }
}
foreach ($folder in $Merged) {
    $names = @($files | Where-Object { $_.StartsWith("$folder/") } | ForEach-Object { ($_ -split '/')[1] } | Sort-Object -Unique)
    foreach ($n in $names) { Add-Item "$folder/$n" (Join-Path $Target "$folder\$n") }
}
foreach ($f in "claude-plugin-marketplace", "CLAUDE.md", "install.ps1", "retired.txt", "settings.template.json") { Add-Item $f (Join-Path $Target $f) }
if ($ShareRoot) {
    Add-Item "create-symlinks.bat" (Join-Path $ShareRoot "create-symlinks.bat")
    $readme = @($files | Where-Object { $_ -eq "docs/share/README.md" })
    if ($readme.Count) { [void]$items.Add([pscustomobject]@{ repoRel = "docs/share/README.md"; dest = (Join-Path $ShareRoot "README.md"); files = $readme }) }
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$script:BackupDir = Join-Path $BackupRoot "publish-$stamp"
$commit = (& git -C $Repo rev-parse --short HEAD 2>$null)
$script:Manifest = [pscustomobject]@{ created = (Get-Date).ToString("o"); target = $Target; shareRoot = $ShareRoot; repoCommit = $commit; actions = @() }
$staging = Join-Path $(if ($ShareRoot) { $ShareRoot } else { Split-Path $Target -Parent }) ".publish-staging-$stamp"

Write-Host "Publishing claude-stash $commit to $Target ($($items.Count) items)"
if ($WhatIf) { Write-Host "Preview only (-WhatIf): nothing will be changed.`n" -ForegroundColor Cyan }
else {
    New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null
    Save-Manifest
    Write-Host "Backup folder: $script:BackupDir`n" -ForegroundColor Cyan
}

# ---------------------------------------------------------------- stage, then swap

$i = 0
foreach ($it in $items) {
    $i++
    $it | Add-Member -NotePropertyName staged -NotePropertyValue (Join-Path $staging $i) -Force
    if ($WhatIf) { continue }
    $single = ($it.files.Count -eq 1 -and $it.files[0] -eq $it.repoRel)
    foreach ($f in $it.files) {
        $rest = if ($single) { "" } else { $f.Substring($it.repoRel.Length + 1) -replace '/', '\' }
        $to = if ($single) { $it.staged } else { Join-Path $it.staged $rest }
        $p = Split-Path $to -Parent
        if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
        Copy-Item -LiteralPath (Join-Path $Repo $f) -Destination $to -Force
    }
}

$skipped = @()
foreach ($it in $items) {
    $key = Get-Key $it.dest
    $exists = Test-Path -LiteralPath $it.dest
    if ($WhatIf) { Say $(if ($exists) { "OVER  " } else { "NEW   " }) $key $(if ($exists) { "Yellow" } else { "Green" }); continue }
    $bak = Join-Path $script:BackupDir "files\$key"
    if ($exists) {
        try { Move-Safe $it.dest $bak }
        catch { $skipped += "$key ($($_.Exception.Message))"; Say "SKIP  " "$key (in use; left as it was)" Red; continue }
        Add-Action @{ action = 'replace'; dest = $it.dest; key = $key }
    }
    else {
        # Folders the publish creates (e.g. Prod\agent-tasks) are recorded before the item in them, so
        # rollback removes the item first and then the (now empty) folder.
        $missing = @(); $p = Split-Path $it.dest -Parent
        while ($p -and -not (Test-Path -LiteralPath $p)) { $missing = @($p) + $missing; $p = Split-Path $p -Parent }
        foreach ($m in $missing) { New-Item -ItemType Directory -Path $m | Out-Null; Add-Action @{ action = 'mkdir'; dest = $m; key = (Get-Key $m) } }
        Add-Action @{ action = 'create'; dest = $it.dest; key = $key }
    }
    try { Move-Safe $it.staged $it.dest }
    catch {
        # Put the old one back so the share is never left without the item.
        if ($exists) { Move-Safe $bak $it.dest }
        $script:Manifest.actions = @($script:Manifest.actions | Where-Object { -not ($_.action -eq 'create' -and $_.dest -eq $it.dest) }); Save-Manifest
        $skipped += "$key ($($_.Exception.Message))"; Say "SKIP  " "$key (could not be put in place; old one kept)" Red; continue
    }
    Say $(if ($exists) { "OVER  " } else { "NEW   " }) $key $(if ($exists) { "Yellow" } else { "Green" })
}

# Retired items
foreach ($line in Get-Content -LiteralPath (Join-Path $Repo "retired.txt")) {
    $r = $line.Trim()
    if (-not $r -or $r.StartsWith('#')) { continue }
    if ($r.Contains('..') -or [IO.Path]::IsPathRooted($r)) { continue }
    $dest = Join-Path $Target ($r -replace '/', '\')
    if (-not (Test-Path -LiteralPath $dest)) { continue }
    $key = Get-Key $dest
    if (-not $WhatIf) {
        try { Move-Safe $dest (Join-Path $script:BackupDir "files\$key"); Add-Action @{ action = 'delete'; dest = $dest; key = $key } }
        catch { $skipped += "$key ($($_.Exception.Message))"; continue }
    }
    Say "DELETE" "$key (retired; backed up)" Yellow
}

if (-not $WhatIf -and (Test-Path -LiteralPath $staging)) { & cmd.exe /c rmdir /s /q "$staging" }

# Items on the share that this repo doesn't hold: left alone, listed so they can be cleaned up by hand.
$ours = @($items | ForEach-Object { $_.dest })
$others = @()
foreach ($c in Get-ChildItem -LiteralPath $Target -Force) {
    if ($Merged -contains $c.Name -and $c.PSIsContainer) {
        foreach ($g in Get-ChildItem -LiteralPath $c.FullName -Force) { if ($ours -notcontains $g.FullName) { $others += "$($c.Name)\$($g.Name)" } }
    }
    elseif ($ours -notcontains $c.FullName) { $others += $c.Name }
}
if ($others.Count) {
    Write-Host "`n[NOTE]   On $Target but not in this repo (left alone):" -ForegroundColor Cyan
    $others | ForEach-Object { Write-Host "         $_" }
}

if ($skipped.Count) {
    Write-Host "`n[WARN]   Not published (old copy kept). Run again when nobody is using them:" -ForegroundColor Yellow
    $skipped | ForEach-Object { Write-Host "         $_" -ForegroundColor Yellow }
}
if ($WhatIf) { Write-Host "`nPreview done. Nothing was changed." -ForegroundColor Cyan }
else {
    Write-Host "`nDone. Backup and manifest: $script:BackupDir" -ForegroundColor Cyan
    Write-Host "To undo:  .\publish-to-prod.ps1 -Rollback `"$script:BackupDir`"" -ForegroundColor Cyan
    Write-Host "Team members pick up changes the next time Claude Code starts. A new skill or file needs"
    Write-Host "them to run create-symlinks.bat again (agents, hooks and the other whole-folder links don't)."
}
if ($skipped.Count) { exit 1 }
