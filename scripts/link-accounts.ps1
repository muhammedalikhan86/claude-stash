<#
.SYNOPSIS
  Points every other Claude Code account folder on this machine at ~/.claude, so one install reaches all.

.DESCRIPTION
  Reads the claude-account-switcher's list (~/.claude-accounts/accounts.json). For each account whose
  folder is not the main one (-MainDir):
    - The shared folders (skills, agents, agent-notes, agent-tasks, commands, hooks, output-styles,
      rules, memory, mods, plugins) become junctions to the same folders in the main one. A junction
      needs no administrator window. A real folder there is moved into the backup first; a junction
      that already points at the main folder is left alone.
    - CLAUDE.md: copied from the main folder each run.
    - settings.json: copied from the main folder when the account has none. When it has one that
      lacks a setting the main one has (a key, or an array item), it is left alone and the main one is
      written beside it as settings.stash.json, to merge by hand (as install.ps1 does). A value that
      only differs is the account's own choice and writes nothing; with nothing missing, an old
      settings.stash.json is deleted.
  Never touches a login (.credentials.json, .claude.json), sessions, projects, history or caches: each
  account keeps its own. install.ps1 runs this at the end of a normal install.

.EXAMPLE
  pwsh scripts/link-accounts.ps1 -WhatIf   # preview; changes nothing
  pwsh scripts/link-accounts.ps1
#>
[CmdletBinding()]
param(
    [switch]$WhatIf,
    [string]$MainDir = (Join-Path $env:USERPROFILE ".claude"),
    [string]$AccountsFile = (Join-Path $env:USERPROFILE ".claude-accounts\accounts.json"),
    [string]$BackupRoot = (Join-Path $env:USERPROFILE ".claude-backups")
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "settings-diff.ps1")
$Shared = "skills", "agents", "agent-notes", "agent-tasks", "commands", "hooks", "output-styles", "rules", "memory", "mods", "plugins"
$MainDir = [IO.Path]::GetFullPath($MainDir).TrimEnd('\')

function Say([string]$Tag, [string]$Text, [string]$Color = "Gray") {
    if ($WhatIf) { $Tag = "WHATIF $Tag" }
    Write-Host ("[{0}] {1}" -f $Tag, $Text) -ForegroundColor $Color
}

if (-not (Test-Path -LiteralPath $AccountsFile)) { Say "SKIP  " "no account list ($AccountsFile): only one account on this machine"; return }
$accounts = @((Get-Content -Raw -LiteralPath $AccountsFile | ConvertFrom-Json).accounts)
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"

foreach ($acc in $accounts) {
    $dir = [IO.Path]::GetFullPath([string]$acc.dir).TrimEnd('\')
    if ($dir -ieq $MainDir) { continue }
    $home_ = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\')
    if (-not $dir.StartsWith("$home_\.claude-", [StringComparison]::OrdinalIgnoreCase)) {
        Say "SKIP  " "$($acc.name): $dir is not a ~\.claude-<name> folder" Yellow; continue
    }
    if (-not (Test-Path -LiteralPath $dir)) { Say "SKIP  " "$($acc.name): $dir does not exist yet (open the account once)" Yellow; continue }
    Write-Host "`n$($acc.name) ($dir)" -ForegroundColor Cyan
    $backup = Join-Path $BackupRoot "accounts-$($acc.name)-$stamp"

    foreach ($name in $Shared) {
        $target = Join-Path $MainDir $name
        $path = Join-Path $dir $name
        if (-not (Test-Path -LiteralPath $target)) { continue }
        $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        if ($item -and $item.LinkType) {
            $to = [IO.Path]::GetFullPath([string]@($item.Target)[0]).TrimEnd('\')
            if ($to -ieq $target) { Say "OK    " "$name (already linked)"; continue }
            if (-not $WhatIf) { [IO.Directory]::Delete($path) }   # removes the link only, never its target
            Say "RELINK" "$name (was linked to $to)" Yellow
        }
        elseif ($item) {
            if (-not $WhatIf) {
                New-Item -ItemType Directory -Force -Path $backup | Out-Null
                Move-Item -LiteralPath $path -Destination (Join-Path $backup $name)
            }
            Say "BACKUP" "$name -> $backup\$name" Yellow
        }
        if (-not $WhatIf) { New-Item -ItemType Junction -Path $path -Target $target | Out-Null }
        Say "LINK  " "$name -> $target" Green
    }

    $src = Join-Path $MainDir "CLAUDE.md"
    if (Test-Path -LiteralPath $src) {
        if (-not $WhatIf) { Copy-Item -LiteralPath $src -Destination (Join-Path $dir "CLAUDE.md") -Force }
        Say "COPY  " "CLAUDE.md" Green
    }

    $mainSettings = Join-Path $MainDir "settings.json"
    $settings = Join-Path $dir "settings.json"
    if (Test-Path -LiteralPath $mainSettings) {
        if (-not (Test-Path -LiteralPath $settings)) {
            if (-not $WhatIf) { Copy-Item -LiteralPath $mainSettings -Destination $settings }
            Say "NEW   " "settings.json (from the main account)" Green
        }
        else {
            $stash = Join-Path $dir "settings.stash.json"
            $missing = @(Get-MissingSettings (Get-Content -Raw -LiteralPath $mainSettings) (Get-Content -Raw -LiteralPath $settings))
            if ($missing.Count) {
                if (-not $WhatIf) { Copy-Item -LiteralPath $mainSettings -Destination $stash -Force }
                Say "NOTE  " "settings.json lacks $($missing.Count) setting(s) the main account has; wrote settings.stash.json beside it to merge:" Cyan
                $missing | ForEach-Object { Write-Host "           $_" }
            }
            else {
                if ((Test-Path -LiteralPath $stash) -and -not $WhatIf) { Remove-Item -LiteralPath $stash -Force }
                Say "OK    " "settings.json (has everything the main account's has)"
            }
        }
    }
}
if (-not $WhatIf) { Write-Host "`nDone. Restart Claude Code in each account to pick it up." -ForegroundColor Cyan }
