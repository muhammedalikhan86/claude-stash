<#
.SYNOPSIS
  Installs the claude-stash skills, agents, hooks, rules, memory, mods and output styles
  into this user's Claude Code folder (~/.claude).

.DESCRIPTION
  Copies real files (no symlinks, no network share). Anything that already exists is skipped
  unless -Force is given. Old symlinks to \\sic2tfs1\Claude\Prod are always replaced, because
  they point at the share this repo replaces.

  settings.json is never overwritten. If you have none, one is written from
  settings.template.json. If you have one, settings.stash.json is written next to it for you
  to merge by hand.

.EXAMPLE
  .\install.ps1
  .\install.ps1 -Context7Key ctx7sk-...      # fills the Context7 key into a new settings.json
  .\install.ps1 -Force                         # overwrite files that already exist
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [string]$Context7Key = "",
    [string]$ClaudeDir = (Join-Path $env:USERPROFILE ".claude")
)

$ErrorActionPreference = "Stop"
$Repo = $PSScriptRoot

function Test-IsLink([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $item = Get-Item -LiteralPath $Path -Force
    return [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
}

function Remove-Link([string]$Path) {
    # Removes only the link itself, never the files it points at.
    (Get-Item -LiteralPath $Path -Force).Delete()
}

function Install-Item([string]$Source, [string]$Target) {
    $name = $Target.Substring($ClaudeDir.Length).TrimStart('\')
    if (Test-IsLink $Target) {
        Write-Host "[RELINK] $name was a symlink -> replacing with real files" -ForegroundColor Yellow
        Remove-Link $Target
    }
    elseif (Test-Path -LiteralPath $Target) {
        if (-not $Force) { Write-Host "[SKIP]   $name (exists; use -Force to overwrite)"; return }
        Remove-Item -LiteralPath $Target -Recurse -Force
        Write-Host "[OVER]   $name" -ForegroundColor Yellow
    }
    $parent = Split-Path $Target -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent | Out-Null }
    Copy-Item -LiteralPath $Source -Destination $Target -Recurse
    Write-Host "[COPY]   $name" -ForegroundColor Green
}

Write-Host "Installing claude-stash into $ClaudeDir`n"
if (-not (Test-Path $ClaudeDir)) { New-Item -ItemType Directory -Path $ClaudeDir | Out-Null }

# Folders installed one child at a time, so a dev's own extra skills/agents are left alone.
$merged = "skills", "agents", "agent-notes", "commands", "hooks", "output-styles", "rules", "memory", "mods"
foreach ($folder in $merged) {
    $target = Join-Path $ClaudeDir $folder
    if (Test-IsLink $target) {
        Write-Host "[RELINK] $folder was a symlink -> replacing with a real folder" -ForegroundColor Yellow
        Remove-Link $target
    }
    if (-not (Test-Path $target)) { New-Item -ItemType Directory -Path $target | Out-Null }
    Get-ChildItem -LiteralPath (Join-Path $Repo $folder) -Force | ForEach-Object {
        Install-Item $_.FullName (Join-Path $target $_.Name)
    }
}

# Global instructions
Install-Item (Join-Path $Repo "CLAUDE.md") (Join-Path $ClaudeDir "CLAUDE.md")

# settings.json
$template = Get-Content -Raw (Join-Path $Repo "settings.template.json")
$template = $template.Replace("__CLAUDE_DIR__", $ClaudeDir.Replace('\', '\\'))
if ($Context7Key) { $template = $template.Replace("__CONTEXT7_API_KEY__", $Context7Key) }
$settings = Join-Path $ClaudeDir "settings.json"
if (Test-Path $settings) {
    $out = Join-Path $ClaudeDir "settings.stash.json"
    Set-Content -Path $out -Value $template -Encoding UTF8
    Write-Host "`n[NOTE]   settings.json already exists. Wrote settings.stash.json next to it." -ForegroundColor Cyan
    Write-Host "         Merge the hooks / env / permissions you want, then delete settings.stash.json."
}
else {
    Set-Content -Path $settings -Value $template -Encoding UTF8
    Write-Host "`n[COPY]   settings.json (from template)" -ForegroundColor Green
}
if (-not $Context7Key) {
    Write-Host "[TODO]   Put your Context7 API key in settings.json (CONTEXT7_API_KEY). Free key: https://context7.com" -ForegroundColor Cyan
}

Write-Host @"

[TODO]   Shaw database password: ask the team lead, then replace <DB_PASSWORD> in
         $ClaudeDir\rules\shaw-estate.md
[TODO]   Hooks need Git Bash ('bash' on PATH) and Python 3.
[TODO]   Public skills are not copied here. Install them with the commands in README.md
         ("Public skills" section).

Done. Restart Claude Code (or run /reload-plugins) to pick everything up.
"@
