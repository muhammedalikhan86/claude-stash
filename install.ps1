<#
.SYNOPSIS
  Installs the claude-stash skills, agents, agent task files, hooks, rules, memory, mods and output
  styles into this user's Claude Code folder (~/.claude), with a full backup and a rollback.

.DESCRIPTION
  Every item this repo holds is installed as real files. Before anything in ~/.claude is replaced or
  deleted, it is copied to ~/.claude-backups/install-<date-time>/, and every change is written to that
  folder's manifest.json as it happens. -Rollback <that folder> undoes the install from the manifest.

  What it does, in order:
    1. Folders that are symlinks to the old \\sic2tfs1\Claude\Prod share (e.g. agents, hooks): the link
       is backed up (its target recorded, its contents copied), then only the link is removed and a real
       folder takes its place. Anything in it that this repo does not have is copied back in from the
       backup, so nothing goes missing. Nothing on the share is ever written or deleted.
    2. Each item this repo holds (skills/<x>, agents/<x>.md, agent-tasks/<x>, ...) and CLAUDE.md is backed
       up if present, removed (only the link, if it is a link), and copied fresh from the repo. Only files
       git tracks or would track are copied, so ignored junk (node_modules, __pycache__) never goes in.
       Generated files the repo ignores on purpose (.claude-plugin/types, .last_update_check) are kept.
       A hard-linked CLAUDE.md gets its own copy, so the other name (another account) keeps its text.
    3. Each path in retired.txt (things this repo used to install, now renamed or retired) is backed up
       and deleted.
    4. settings.json is never overwritten. If you have none, one is written from settings.template.json;
       if you have one, settings.stash.json is written beside it (the old stash is backed up first).
  Everything else in ~/.claude (your own skills, public skills, links to ~/.agents) is left alone.

  The Shaw database password in rules/shaw-estate.md is carried over from your old copy if it had one.

  -Link (what create-symlinks.bat runs): instead of copying from this repo, links ~/.claude to the
  team's shared copies on the PROD share (-ProdDir), which publish-to-prod.ps1 fills from this repo:
    - agents, agent-notes, agent-tasks, hooks, output-styles, commands: the whole folder is linked. If
      your folder holds items of your own, each shared item is linked one by one instead and yours stay.
    - skills, memory, rules: each shared item is linked one by one; your own items stay.
    - CLAUDE.md: linked, so every account on the machine reads the same file.
    - Copied, not linked: rules/shaw-estate.md (it holds your DB password) and mods (they write into
      their own folder).
  Same backup, manifest and rollback as above. Making a symlink needs an administrator window. Nothing
  on the share is ever written; this mode only reads it.

.EXAMPLE
  .\install.ps1 -WhatIf                         # preview every step; changes nothing
  .\install.ps1 -KeepBackups 0                  # keep every old backup (default keeps the newest 3)
  .\install.ps1                                 # install (backs up first)
  .\install.ps1 -Context7Key ctx7sk-...         # also fill the Context7 key into a new settings.json
  .\install.ps1 -Link -ClaudeDir "$env:USERPROFILE\.claude-lachlan"   # link one account to PROD (admin)
  .\install.ps1 -Rollback "$env:USERPROFILE\.claude-backups\install-claude-20261110-153000"
  .\install.ps1 -Rollback "<backup folder>" -WhatIf   # preview the rollback
#>
[CmdletBinding()]
param(
    [switch]$WhatIf,
    [string]$Rollback = "",
    [string]$Context7Key = "",
    [string]$ClaudeDir = (Join-Path $env:USERPROFILE ".claude"),
    [string]$BackupRoot = (Join-Path $env:USERPROFILE ".claude-backups"),
    [int]$KeepBackups = 3,   # after a good run, older backups of the same kind and folder beyond this many are deleted
    [switch]$Link,
    [string]$ProdDir = "\\sic2tfs1\Claude\Prod",
    [switch]$Force   # kept for old instructions; items are now always replaced (with a backup)
)

$ErrorActionPreference = "Stop"
$Repo = $PSScriptRoot
$ClaudeDirGiven = $PSBoundParameters.ContainsKey('ClaudeDir')
$ClaudeDir = [IO.Path]::GetFullPath($ClaudeDir).TrimEnd('\')
$ProdDir = $ProdDir.TrimEnd('\')
$Src = if ($Link) { $ProdDir } else { $Repo }   # where the items come from
$Merged = "skills", "agents", "agent-notes", "agent-tasks", "commands", "hooks", "output-styles", "rules", "memory", "mods"
$KeepGenerated = ".claude-plugin\types", ".last_update_check"
# -Link: folders linked whole; items copied rather than linked.
$LinkFolders = "agents", "agent-notes", "agent-tasks", "hooks", "output-styles", "commands"
$CopyItemsInLinkMode = @("rules\shaw-estate.md")
$CopyFoldersInLinkMode = @("mods")
# Tests only: this account can't make symlinks, so the sandbox uses junctions (folders) and hard links (files).
$TestLinks = $env:CLAUDE_STASH_TEST_LINKS -eq '1'

# ---------------------------------------------------------------- helpers

function Say([string]$Tag, [string]$Text, [string]$Color = "Gray") {
    if ($WhatIf) { $Tag = "WHATIF $Tag" }
    Write-Host ("[{0}] {1}" -f $Tag, $Text) -ForegroundColor $Color
}

function Assert-Inside([string]$Path) {
    # Refuse to change anything outside ~/.claude (or the backup folder).
    $full = [IO.Path]::GetFullPath($Path)
    $okRoots = @($ClaudeDir + '\')
    if ($script:BackupDir) { $okRoots += ([IO.Path]::GetFullPath($script:BackupDir).TrimEnd('\') + '\') }
    foreach ($r in $okRoots) { if ($full.StartsWith($r, [StringComparison]::OrdinalIgnoreCase)) { return } }
    throw "Refusing to touch a path outside $ClaudeDir : $full"
}

$Utf8 = New-Object System.Text.UTF8Encoding($false)   # UTF-8 with no BOM (Windows PowerShell's default reads/writes are not)

function Read-Text([string]$Path) { return [IO.File]::ReadAllText($Path, $Utf8) }   # also handles a BOM if present
function Write-Text([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text, $Utf8) }

function Get-LinkedParent([string]$Path) {
    # The first folder above $Path (up to ~/.claude) that is a link, or $null. Writing or deleting under
    # such a folder would change the link's target (e.g. the share), so callers refuse.
    $p = Split-Path ([IO.Path]::GetFullPath($Path)) -Parent
    while ($p -and $p.Length -gt $ClaudeDir.Length) {
        if (Test-Path -LiteralPath $p) {
            $lt = (Get-Item -LiteralPath $p -Force).LinkType
            if ($lt -eq 'SymbolicLink' -or $lt -eq 'Junction') { return $p }
        }
        $p = Split-Path $p -Parent
    }
    return $null
}

function Assert-NoLinkedParent([string]$Path) {
    $lp = Get-LinkedParent $Path
    if ($lp) { throw "Refusing to change $Path : the folder $lp above it is a link, so the change would land on the link's target." }
}

function Get-Kind([string]$Path) {
    $i = Get-Item -LiteralPath $Path -Force
    if ($i.LinkType -eq 'SymbolicLink') { return 'symlink' }
    if ($i.LinkType -eq 'Junction') { return 'junction' }
    if ($i.PSIsContainer) { return 'dir' }
    if ($i.LinkType -eq 'HardLink') { return 'hardlink' }
    return 'file'
}

function Format-LinkTarget($t) {
    # Windows PowerShell reports a share target as "UNC\server\share"; make it a real path again.
    if ($t -is [array]) { $t = $t[0] }
    $t = [string]$t
    if ($t.StartsWith('\??\UNC\')) { return '\\' + $t.Substring(8) }
    if ($t.StartsWith('\??\')) { return $t.Substring(4) }
    if ($t.StartsWith('UNC\')) { return '\\' + $t.Substring(4) }
    return $t
}

function Get-LinkTarget([string]$Path) {
    return Format-LinkTarget (Get-Item -LiteralPath $Path -Force).Target
}

function Get-OtherHardLinks([string]$Path) {
    # Other names of a hard-linked file (e.g. another account's CLAUDE.md).
    $drive = [IO.Path]::GetPathRoot($Path).TrimEnd('\')
    $full = [IO.Path]::GetFullPath($Path)
    $names = @(& fsutil hardlink list $Path 2>$null) | Where-Object { $_ } | ForEach-Object { $drive + $_.Trim() }
    return @($names | Where-Object { -not $_.Equals($full, [StringComparison]::OrdinalIgnoreCase) })
}

function Test-Exists([string]$Path) {
    # True for a real item or a link, even a link whose target is unreachable.
    if (Test-Path -LiteralPath $Path) { return $true }
    try { $null = Get-Item -LiteralPath $Path -Force -ErrorAction Stop; return $true } catch { return $false }
}

function Remove-Target([string]$Path) {
    # Removes the item at $Path. A link is removed on its own; its target is never touched.
    Assert-Inside $Path
    if (-not (Test-Exists $Path)) { return }
    if ($WhatIf) { return }
    Assert-NoLinkedParent $Path
    $i = Get-Item -LiteralPath $Path -Force
    if ($i.LinkType -eq 'SymbolicLink' -or $i.LinkType -eq 'Junction') {
        $i.Delete()                                   # deletes the link only
    }
    elseif ($i.PSIsContainer) {
        & cmd.exe /c rmdir /s /q "$Path"              # rmdir never follows links inside the folder
        if (Test-Path -LiteralPath $Path) { throw "Could not remove $Path" }
    }
    else {
        Remove-Item -LiteralPath $Path -Force         # a hard link: removes this name only
    }
}

function Save-Manifest {
    if ($WhatIf) { return }
    # Write a temp file, then swap it in, so a kill mid-write never leaves a half-written manifest.
    $mf = Join-Path $script:BackupDir "manifest.json"
    $tmp = "$mf.tmp"
    Write-Text $tmp ($script:Manifest | ConvertTo-Json -Depth 6)
    Move-Item -LiteralPath $tmp -Destination $mf -Force
}

function Add-Action([hashtable]$Action) {
    $script:Manifest.actions += [pscustomobject]$Action
    Save-Manifest
}

function Copy-Tree([string]$Src, [string]$Dst, [string]$Rel, [System.Collections.ArrayList]$Links) {
    # Copies a file or folder without following links inside it; each inner link is recorded instead
    # (its path relative to ~/.claude, its type and target), so rollback can re-make it.
    $i = Get-Item -LiteralPath $Src -Force
    if (-not $i.PSIsContainer) { Copy-Item -LiteralPath $Src -Destination $Dst -Force; return }
    New-Item -ItemType Directory -Path $Dst -Force | Out-Null
    foreach ($c in Get-ChildItem -LiteralPath $Src -Force) {
        $cRel = Join-Path $Rel $c.Name
        if ($c.LinkType -eq 'SymbolicLink' -or $c.LinkType -eq 'Junction') {
            [void]$Links.Add([pscustomobject]@{ path = $cRel; type = [string]$c.LinkType; target = (Format-LinkTarget $c.Target) })
        }
        else { Copy-Tree $c.FullName (Join-Path $Dst $c.Name) $cRel $Links }
    }
}

function Backup-Item([string]$Rel) {
    # Copies the item at ~/.claude/<Rel> into the backup folder and returns what rollback needs.
    $src = Join-Path $ClaudeDir $Rel
    $dst = Join-Path (Join-Path $script:BackupDir "files") $Rel
    $kind = Get-Kind $src
    $info = @{ path = $Rel; kind = $kind; backup = "files\$Rel"; linkTarget = $null; contentCopied = $false; otherHardLinks = @(); innerLinks = @() }
    if ($kind -eq 'symlink' -or $kind -eq 'junction') { $info.linkTarget = Get-LinkTarget $src }
    if ($kind -eq 'hardlink') { $info.otherHardLinks = @(Get-OtherHardLinks $src) }
    if ($WhatIf) { $info.contentCopied = $true; return $info }
    $parent = Split-Path $dst -Parent
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    try {
        # Reading through a link copies what it points at; nothing at the target is changed.
        # Links inside the item are recorded, not followed.
        $links = New-Object System.Collections.ArrayList
        Copy-Tree $src $dst $Rel $links
        $info.contentCopied = $true
        $info.innerLinks = @($links)   # for a link, rollback re-makes the link itself and ignores these
    }
    catch {
        if ($info.linkTarget) {
            Write-Host "[WARN] could not copy the contents behind link $Rel ($($info.linkTarget)); its target is recorded so rollback can re-link it." -ForegroundColor Yellow
        }
        else { throw "Backup of $Rel failed, so nothing was changed for it: $_" }
    }
    return $info
}

function Get-RepoFiles {
    # Files git tracks or would track (respects .gitignore), and that exist on disk.
    $list = $null
    try { $list = @(& git -C $Repo ls-files --cached --others --exclude-standard 2>$null) } catch { }
    if (-not $list -or $LASTEXITCODE -ne 0) { return $null }
    return @($list | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $Repo $_) -PathType Leaf) })
}

function Copy-FromRepo([string]$Rel, [string]$SrcRel = $Rel) {
    # Copies the source's item <SrcRel> (a file or a folder; the repo, or PROD with -Link) to ~/.claude/<Rel>.
    $src = Join-Path $Src $SrcRel
    $dst = Join-Path $ClaudeDir $Rel
    Assert-Inside $dst
    if ($WhatIf) { return }
    Assert-NoLinkedParent $dst
    if ($script:RepoFiles -and (Test-Path -LiteralPath $src -PathType Container)) {
        $prefix = ($Rel -replace '\\', '/') + '/'
        foreach ($f in $script:RepoFiles | Where-Object { $_.StartsWith($prefix) }) {
            $to = Join-Path $ClaudeDir ($f -replace '/', '\')
            $p = Split-Path $to -Parent
            if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
            Copy-Item -LiteralPath (Join-Path $Repo $f) -Destination $to -Force
        }
    }
    else {
        $p = Split-Path $dst -Parent
        if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
        Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
    }
}

function Restore-Generated([string]$Rel, $Info) {
    # Puts back generated files the repo ignores on purpose (e.g. mod type stubs).
    if ($WhatIf -or -not $Info -or -not $Info.contentCopied) { return }
    $bak = Join-Path $script:BackupDir $Info.backup
    if (-not (Test-Path -LiteralPath $bak -PathType Container)) { return }
    foreach ($k in $KeepGenerated) {
        $from = Join-Path $bak $k
        $to = Join-Path (Join-Path $ClaudeDir $Rel) $k
        if ((Test-Path -LiteralPath $from) -and -not (Test-Path -LiteralPath $to)) {
            Copy-Item -LiteralPath $from -Destination $to -Recurse -Force
            Write-Host "[KEEP]   $Rel\$k (generated, kept from your old copy)" -ForegroundColor DarkGray
        }
    }
}

function Restore-DbPassword($Info) {
    # Carries the Shaw DB password from the old rules/shaw-estate.md into the new one.
    if (-not $Info -or -not $Info.contentCopied) { return }
    $old = Join-Path $script:BackupDir $Info.backup
    if ($WhatIf) { $old = Join-Path $ClaudeDir "rules\shaw-estate.md" }
    $new = Join-Path $ClaudeDir "rules\shaw-estate.md"
    if (-not (Test-Path -LiteralPath $old -PathType Leaf) -or -not (Test-Path -LiteralPath $new)) { return }
    $m = [regex]::Match((Read-Text $old), 'Password=([^;<\s"]+);')
    $text = Read-Text $new
    if ($WhatIf) { $text = Read-Text (Join-Path $Src "rules\shaw-estate.md") }
    if ($m.Success -and $text.Contains('<DB_PASSWORD>')) {
        if (-not $WhatIf) { Write-Text $new $text.Replace('<DB_PASSWORD>', $m.Groups[1].Value) }
        Write-Host "[KEEP]   rules\shaw-estate.md: DB password carried over from your old copy" -ForegroundColor DarkGray
        $script:PasswordKept = $true
    }
}

function Install-RepoItem([string]$Rel, [string]$SrcRel = $Rel) {
    $target = Join-Path $ClaudeDir $Rel
    Assert-Inside $target
    $info = $null
    if (Test-Exists $target) {
        $info = Backup-Item $Rel
        $info.action = 'replace'
        Add-Action $info
        $what = switch ($info.kind) { 'symlink' { "was a link to $($info.linkTarget); link removed, real files put in" } 'junction' { "was a junction; junction removed, real files put in" } 'hardlink' { "was a hard link; now its own copy (other names keep theirs)" } default { "replaced" } }
        Remove-Target $target
        Copy-FromRepo $Rel $SrcRel
        Say "OVER  " "$Rel ($what)" Yellow
    }
    else {
        Add-Action @{ action = 'create'; path = $Rel }
        Copy-FromRepo $Rel $SrcRel
        Say "NEW   " $Rel Green
    }
    Restore-Generated $Rel $info
    if ($Rel -eq 'rules\shaw-estate.md') { Restore-DbPassword $info }
}

function Test-LinkedTo([string]$Path, [string]$To) {
    # True if $Path is already a link to $To.
    if (-not (Test-Exists $Path)) { return $false }
    $k = Get-Kind $Path
    if ($k -in 'symlink', 'junction') { return (Get-LinkTarget $Path).TrimEnd('\').Equals($To.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase) }
    if ($TestLinks -and $k -eq 'hardlink') { return @(Get-OtherHardLinks $Path) -contains [IO.Path]::GetFullPath($To) }
    return $false
}

function New-LinkAt([string]$Path, [string]$To) {
    $type = 'SymbolicLink'
    if ($TestLinks) { $type = if (Test-Path -LiteralPath $To -PathType Container) { 'Junction' } else { 'HardLink' } }
    New-Item -ItemType $type -Path $Path -Target $To -ErrorAction Stop | Out-Null
}

function Link-Item([string]$Rel) {
    # -Link: makes ~/.claude/<Rel> a link to <ProdDir>/<Rel>, backing up what was there.
    $target = Join-Path $ClaudeDir $Rel
    $to = Join-Path $ProdDir $Rel
    Assert-Inside $target
    if (-not (Test-Path -LiteralPath $to)) { Say "SKIP  " "$Rel (not on $ProdDir)" Yellow; return }
    if (Test-LinkedTo $target $to) { Say "OK    " "$Rel (already linked)" DarkGray; return }
    $info = $null
    if (Test-Exists $target) { $info = Backup-Item $Rel; $info.action = 'replace'; Add-Action $info }
    else { Add-Action @{ action = 'create'; path = $Rel } }
    if (-not $WhatIf) {
        Assert-NoLinkedParent $target
        $p = Split-Path $target -Parent
        if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
        # Made under a temporary name first, so if the link can't be made the old item is still there.
        $tmp = "$target.link-tmp"
        if (Test-Exists $tmp) { Remove-Target $tmp }
        New-LinkAt $tmp $to
        Remove-Target $target
        Rename-Item -LiteralPath $tmp -NewName (Split-Path $target -Leaf)
    }
    if ($info) { Say "LINK  " "$Rel -> $to (the old one is backed up)" Yellow } else { Say "LINK  " "$Rel -> $to" Green }
}

# ---------------------------------------------------------------- rollback

function Invoke-Rollback([string]$Dir) {
    $Dir = [IO.Path]::GetFullPath($Dir).TrimEnd('\')
    $mf = Join-Path $Dir "manifest.json"
    if (-not (Test-Path -LiteralPath $mf)) { throw "No manifest.json in $Dir" }
    $m = Read-Text $mf | ConvertFrom-Json
    $script:BackupDir = $Dir
    # Whatever is there now (including edits made after the install) is saved here before rollback removes it.
    $saveDir = Join-Path $Dir ("before-rollback-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    $saved = $false
    # The backup knows which folder it came from; use that unless -ClaudeDir was passed.
    if ($m.claudeDir -and -not $ClaudeDirGiven) { $script:ClaudeDir = $ClaudeDir = $m.claudeDir }
    if ($m.claudeDir -and -not $m.claudeDir.Equals($ClaudeDir, [StringComparison]::OrdinalIgnoreCase)) {
        throw "This backup was taken from $($m.claudeDir), not $ClaudeDir. Pass -ClaudeDir `"$($m.claudeDir)`"."
    }
    Write-Host "Rolling back the install of $($m.created) in $ClaudeDir`n"
    $failedLinks = @()
    $acts = @($m.actions); [array]::Reverse($acts)
    foreach ($a in $acts) {
        $target = Join-Path $ClaudeDir $a.path
        Assert-Inside $target
        if (-not $WhatIf -and (Test-Exists $target) -and -not ((Get-Kind $target) -in 'symlink', 'junction')) {
            $sd = Join-Path $saveDir $a.path
            New-Item -ItemType Directory -Path (Split-Path $sd -Parent) -Force | Out-Null
            $null = Copy-Tree $target $sd $a.path (New-Object System.Collections.ArrayList)
            $saved = $true
        }
        switch ($a.action) {
            { $_ -in 'create', 'mkdir' } {
                Remove-Target $target
                Say "REMOVE" "$($a.path) (added by the install)" Yellow
            }
            { $_ -in 'replace', 'delete', 'unlinkFolder' } {
                $bak = Join-Path $Dir $a.backup
                $restoreFiles = $true
                if ($a.kind -eq 'symlink' -or $a.kind -eq 'junction') {
                    $type = if ($a.kind -eq 'junction') { 'Junction' } else { 'SymbolicLink' }
                    # Make the link under a temporary name first; only once that works is the current item
                    # removed and the link renamed into place. If it can't be made, nothing is lost.
                    $made = $false
                    if (-not $WhatIf) {
                        $tmp = "$target.relink-tmp"
                        try {
                            if (Test-Exists $tmp) { Remove-Target $tmp }
                            New-Item -ItemType $type -Path $tmp -Target $a.linkTarget -ErrorAction Stop | Out-Null
                            Remove-Target $target
                            Rename-Item -LiteralPath $tmp -NewName (Split-Path $target -Leaf)
                            $made = $true
                        }
                        catch {
                            if (Test-Exists $tmp) { try { Remove-Target $tmp } catch { } }
                            $failedLinks += "cmd /c rmdir /s /q `"$target`"   # (or del, for a file) then:"
                            $failedLinks += "New-Item -ItemType $type -Path `"$target`" -Target `"$($a.linkTarget)`""
                        }
                    }
                    if ($made -or $WhatIf) { Say "RELINK" "$($a.path) -> $($a.linkTarget)" Green; $restoreFiles = $false }
                    elseif (-not $a.contentCopied) {
                        Say "WARN  " "$($a.path): could not re-make the link and there is no copy of its contents; left as it is" Yellow
                        $restoreFiles = $false
                    }
                    else { Say "WARN  " "$($a.path): could not re-make the link; its old contents are put back as real files instead" Yellow }
                }
                if ($restoreFiles) {
                    if (-not $WhatIf) { Remove-Target $target }
                    $relinked = $false
                    if ($a.kind -eq 'hardlink' -and -not $WhatIf) {
                        foreach ($o in @($a.otherHardLinks)) {
                            if ($o -and (Test-Path -LiteralPath $o) -and ((Get-FileHash $o).Hash -eq (Get-FileHash $bak).Hash)) {
                                New-Item -ItemType HardLink -Path $target -Target $o | Out-Null; $relinked = $true; break
                            }
                        }
                    }
                    if (-not $relinked -and -not $WhatIf) {
                        $p = Split-Path $target -Parent
                        if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
                        Copy-Item -LiteralPath $bak -Destination $target -Recurse -Force
                        $innerLinks = if ($a.kind -eq 'symlink' -or $a.kind -eq 'junction') { @() } else { @($a.innerLinks) }
                        foreach ($l in $innerLinks) {
                            if (-not $l) { continue }
                            $lp = Join-Path $ClaudeDir $l.path
                            Assert-Inside $lp
                            try { New-Item -ItemType $l.type -Path $lp -Target $l.target | Out-Null }
                            catch { $failedLinks += "New-Item -ItemType $($l.type) -Path `"$lp`" -Target `"$($l.target)`"" }
                        }
                    }
                    Say "RESTORE" $a.path Green
                }
            }
        }
    }
    if ($saved) { Write-Host "`n[NOTE] What was there before this rollback is saved in $saveDir" -ForegroundColor Cyan }
    if ($failedLinks.Count) {
        Write-Host "`n[TODO] These links could not be made. Their old contents were put back as real files, so" -ForegroundColor Cyan
        Write-Host "       Claude Code still works. To get the links back, open PowerShell as administrator" -ForegroundColor Cyan
        Write-Host "       (Windows PowerShell 5.1 needs admin for links even with Developer Mode) and run:" -ForegroundColor Cyan
        $failedLinks | ForEach-Object { Write-Host "       $_" }
    }
    Write-Host "`nRollback done. Restart Claude Code (or run /reload-plugins)."
}

if ($Rollback) { Invoke-Rollback $Rollback; return }

# ---------------------------------------------------------------- install

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$modeName = if ($Link) { "link" } else { "install" }
$script:BackupDir = Join-Path $BackupRoot ("{0}-{1}-{2}" -f $modeName, (Split-Path $ClaudeDir -Leaf).TrimStart('.'), $stamp)
$commit = ""
if (-not $Link) { try { $commit = (& git -C $Repo rev-parse --short HEAD 2>$null) } catch { } }
$script:Manifest = [pscustomobject]@{ created = (Get-Date).ToString("o"); mode = $modeName; claudeDir = $ClaudeDir; source = $Src; repoCommit = $commit; actions = @() }
$script:PasswordKept = $false

if ($Link) { Write-Host "Linking $ClaudeDir to the shared copies in $ProdDir" }
else { Write-Host "Installing claude-stash into $ClaudeDir" }
if ($WhatIf) { Write-Host "Preview only (-WhatIf): nothing will be changed.`n" -ForegroundColor Cyan }

function Stop-Install([int]$Code, [string[]]$Lines) {
    # Ends the run before anything was changed, removing the empty backup folder.
    $Lines | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    if (-not $WhatIf -and (Test-Path -LiteralPath $script:BackupDir)) { Remove-Item -LiteralPath $script:BackupDir -Recurse -Force }
    exit $Code
}

if ($Link) {
    # The share must be readable, and this window must be able to make links, before anything changes.
    try { $null = Get-ChildItem -LiteralPath $ProdDir -Force -ErrorAction Stop }
    catch { Stop-Install 2 @("[STOP]   Can't read $ProdDir. Nothing was changed.", "         Connect to the network (or VPN), then run again.") }
    $probe = Join-Path ([IO.Path]::GetTempPath()) ("claude-link-probe-" + [guid]::NewGuid().ToString('N'))
    try {
        if ($TestLinks) { New-Item -ItemType Junction -Path $probe -Target $ProdDir -ErrorAction Stop | Out-Null }
        else { New-Item -ItemType SymbolicLink -Path $probe -Target $ProdDir -ErrorAction Stop | Out-Null }
        (Get-Item -LiteralPath $probe -Force).Delete()
    }
    catch {
        if ($WhatIf) { Write-Host "[WARN]   this window can't make links; the real run needs an administrator window.`n" -ForegroundColor Yellow }
        else { Stop-Install 3 @("[STOP]   This window can't make links. Nothing was changed.", "         Open Command Prompt or PowerShell as administrator and run again.") }
    }
}

if (-not $WhatIf) {
    New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null
    Save-Manifest
    Write-Host "Backup folder: $script:BackupDir`n" -ForegroundColor Cyan
}
if (-not (Test-Path $ClaudeDir) -and -not $WhatIf) { New-Item -ItemType Directory -Path $ClaudeDir | Out-Null }

$script:RepoFiles = $null
if (-not $Link) {
    $dirty = @(& git -C $Repo status --porcelain 2>$null)
    if ($dirty.Count) { Write-Host "[NOTE]   the repo has uncommitted changes; the working copy is what gets installed." -ForegroundColor Cyan }

    # The plugin Developer agents are generated from orchestrated-developer.md; warn if they are stale.
    try {
        $global:LASTEXITCODE = 0
        & (Join-Path $Repo "scripts\build-developer-agents.ps1") -Check
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[WARN]   generated developer agents are stale or missing (see above). Run scripts\build-developer-agents.ps1, then re-install." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[WARN]   could not check generated developer agents: $_" -ForegroundColor Yellow
    }

    $script:RepoFiles = Get-RepoFiles
    if (-not $script:RepoFiles) { Write-Host "[WARN]   git not available; copying whole folders from the repo instead." -ForegroundColor Yellow }
}

function Get-SourceNames([string]$Folder) {
    # The items the source holds in this folder (in the repo: git-visible ones only, when git is available).
    if ($script:RepoFiles) {
        return @($script:RepoFiles | Where-Object { $_.StartsWith("$Folder/") } | ForEach-Object { ($_ -split '/')[1] } | Sort-Object -Unique)
    }
    return @(Get-ChildItem -LiteralPath (Join-Path $Src $Folder) -Force | ForEach-Object Name)
}

# Pre-flight: every link this run will replace must be readable (so it can be backed up),
# checked before anything is changed.
$unreachable = @()
foreach ($folder in $Merged) {
    if (-not (Test-Path -LiteralPath (Join-Path $Src $folder))) { continue }
    $t = Join-Path $ClaudeDir $folder
    $cands = @($t)
    if (-not ((Test-Exists $t) -and ((Get-Kind $t) -in 'symlink', 'junction'))) {
        $cands += @(Get-SourceNames $folder | ForEach-Object { Join-Path $t $_ })
    }
    foreach ($c in $cands) {
        if ((Test-Exists $c) -and ((Get-Kind $c) -in 'symlink', 'junction')) {
            if ($Link -and (Test-LinkedTo $c (Join-Path $ProdDir $c.Substring($ClaudeDir.Length + 1)))) { continue }   # already right; not replaced
            # Test-Path can say yes for a dangling link, so actually try to list it.
            try { $null = Get-ChildItem -LiteralPath $c -Force -ErrorAction Stop }
            catch { $unreachable += "$c -> $(Get-LinkTarget $c)" }
        }
    }
}
if ($unreachable.Count) {
    Stop-Install 2 (@("[STOP]   These links can't be read, so they can't be backed up. Nothing was changed.") +
        @($unreachable | ForEach-Object { "         $_" }) +
        @("         Connect to the network (or VPN) so the share is reachable, then run again."))
}

function Convert-LinkedFolder([string]$Folder, [string[]]$Names) {
    # A whole folder that is a link: back it up, unlink, keep anything the source doesn't have.
    $target = Join-Path $ClaudeDir $Folder
    $info = Backup-Item $Folder
    if (-not $info.contentCopied) { throw "Could not read the contents behind $Folder ($($info.linkTarget)), so its extra items can't be kept. Nothing in $Folder was changed. Check the share is reachable and run again." }
    $info.action = 'unlinkFolder'
    Add-Action $info
    Remove-Target $target
    if (-not $WhatIf) { New-Item -ItemType Directory -Path $target | Out-Null }
    Say "UNLINK" "$Folder was a link to $($info.linkTarget); link removed, now a real folder (the link's target is untouched)" Yellow
    $bakFolder = Join-Path $script:BackupDir $info.backup
    if (-not $WhatIf) {
        Get-ChildItem -LiteralPath $bakFolder -Force | Where-Object { $Names -notcontains $_.Name } | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $target $_.Name) -Recurse -Force
            Say "KEEP  " "$Folder\$($_.Name) (not in the shared set; kept from the old folder)" DarkGray
        }
        # Links that sat inside the linked folder (the backup holds none) are re-made, unless the source
        # replaces the item they belong to.
        foreach ($l in @($info.innerLinks)) {
            if (-not $l -or $Names -contains (($l.path -split '\\')[1])) { continue }
            $lp = Join-Path $ClaudeDir $l.path
            try {
                New-Item -ItemType $l.type -Path $lp -Target $l.target -ErrorAction Stop | Out-Null
                Say "KEEP  " "$($l.path) (a link; re-made, pointing at $($l.target))" DarkGray
            }
            catch { Write-Host "[TODO]   could not re-make the link $($l.path). As admin: New-Item -ItemType $($l.type) -Path `"$lp`" -Target `"$($l.target)`"" -ForegroundColor Cyan }
        }
    }
    else {
        Get-ChildItem -LiteralPath $target -Force -ErrorAction SilentlyContinue | Where-Object { $Names -notcontains $_.Name } | ForEach-Object {
            Say "KEEP  " "$Folder\$($_.Name) (not in the shared set; kept from the old folder)" DarkGray
        }
    }
}

foreach ($folder in $Merged) {
    if (-not (Test-Path -LiteralPath (Join-Path $Src $folder))) { continue }
    $target = Join-Path $ClaudeDir $folder
    $names = @(Get-SourceNames $folder)

    if ($Link -and $LinkFolders -contains $folder) {
        # Link the whole folder, unless it holds items of the user's own.
        $extras = @()
        if ((Test-Exists $target) -and (Get-Kind $target) -eq 'dir') {
            $extras = @(Get-ChildItem -LiteralPath $target -Force | Where-Object { $names -notcontains $_.Name } | ForEach-Object Name)
        }
        if (-not $extras.Count) { Link-Item $folder; continue }
        Say "NOTE  " "$folder holds items of your own ($($extras -join ', ')); linking each shared item one by one so yours stay" Cyan
    }

    if ((Test-Exists $target) -and ((Get-Kind $target) -in 'symlink', 'junction')) { Convert-LinkedFolder $folder $names }
    elseif (-not (Test-Exists $target)) {
        Add-Action @{ action = 'mkdir'; path = $folder }
        if (-not $WhatIf) { New-Item -ItemType Directory -Path $target | Out-Null }
        Say "NEW   " "$folder\" Green
    }

    foreach ($n in $names) {
        $rel = Join-Path $folder $n
        if (-not $Link -or $CopyItemsInLinkMode -contains $rel -or $CopyFoldersInLinkMode -contains $folder) { Install-RepoItem $rel }
        else { Link-Item $rel }
    }
}

# Global instructions: global/CLAUDE.md in the repo (the repo-root CLAUDE.md is the repo's own);
# CLAUDE.md at the root of a published copy.
$globalSrc = if (Test-Path -LiteralPath (Join-Path $Src "global\CLAUDE.md")) { "global\CLAUDE.md" } else { "CLAUDE.md" }
if ($Link) { Link-Item "CLAUDE.md" } else { Install-RepoItem "CLAUDE.md" $globalSrc }

# Retired items
$retired = Join-Path $Src "retired.txt"
if (Test-Path -LiteralPath $retired) {
    foreach ($line in Get-Content -LiteralPath $retired) {
        $r = $line.Trim()
        if (-not $r -or $r.StartsWith('#')) { continue }
        if ($r.Contains('..') -or [IO.Path]::IsPathRooted($r)) { Write-Host "[WARN]   skipping bad retired.txt line: $r" -ForegroundColor Yellow; continue }
        $rel = $r -replace '/', '\'
        $path = Join-Path $ClaudeDir $rel
        Assert-Inside $path
        if (-not (Test-Exists $path)) { continue }
        $lp = Get-LinkedParent $path
        if ($lp) { Write-Host "[SKIP]   retired $rel : $lp is a link, so deleting it would change the link's target. Left alone." -ForegroundColor Yellow; continue }
        $info = Backup-Item $rel
        $info.action = 'delete'
        Add-Action $info
        Remove-Target $path
        Say "DELETE" "$rel (retired; backed up)" Yellow
    }
}

# settings.json
$template = Read-Text (Join-Path $Src "settings.template.json")
$template = $template.Replace("__CLAUDE_DIR__", $ClaudeDir.Replace('\', '\\'))
if ($Context7Key) { $template = $template.Replace("__CONTEXT7_API_KEY__", $Context7Key) }
$settings = Join-Path $ClaudeDir "settings.json"
if (Test-Path $settings) {
    $out = Join-Path $ClaudeDir "settings.stash.json"
    if (Test-Exists $out) { $info = Backup-Item "settings.stash.json"; $info.action = 'replace'; Add-Action $info }
    else { Add-Action @{ action = 'create'; path = "settings.stash.json" } }
    if (-not $WhatIf) { Remove-Target $out; Write-Text $out $template }   # removed first, so a link there is never written through
    Say "NOTE  " "settings.json already exists (not touched). Wrote settings.stash.json next to it." Cyan
    Write-Host "         Merge the hooks / env / permissions you want, then delete settings.stash.json."
}
else {
    Add-Action @{ action = 'create'; path = "settings.json" }
    if (-not $WhatIf) { Write-Text $settings $template }   # no BOM: Claude Code's JSON reader rejects one
    Say "NEW   " "settings.json (from template)" Green
}
if (-not $Context7Key) {
    Write-Host "[TODO]   Put your Context7 API key in settings.json (CONTEXT7_API_KEY) if it is not there. Free key: https://context7.com" -ForegroundColor Cyan
}
if (-not $script:PasswordKept) {
    Write-Host "[TODO]   Shaw database password: if $ClaudeDir\rules\shaw-estate.md still shows <DB_PASSWORD>, ask the team lead and replace it." -ForegroundColor Cyan
}

Write-Host @"
[TODO]   Hooks need Git Bash ('bash' on PATH) and Python 3.
[TODO]   Public skills are not copied here. Install them with the commands in README.md
         ("Public skills" section).
"@
if ($WhatIf) { Write-Host "`nPreview done. Nothing was changed." -ForegroundColor Cyan }
else {
    Write-Host "`nDone. Backup and manifest: $script:BackupDir" -ForegroundColor Cyan
    # Keep only the newest backups of this kind (install or link) for this folder; this run's is always kept.
    if ($KeepBackups -gt 0) {
        $kind = "{0}-{1}-" -f $modeName, (Split-Path $ClaudeDir -Leaf).TrimStart('.')
        $old = @(Get-ChildItem -LiteralPath $BackupRoot -Directory |
            Where-Object { $_.Name.StartsWith($kind) -and $_.Name -match '\d{8}-\d{6}$' -and $_.FullName -ne $script:BackupDir } |
            Sort-Object Name -Descending | Select-Object -Skip ([Math]::Max(0, $KeepBackups - 1)))
        foreach ($d in $old) {
            try { Remove-Item -LiteralPath $d.FullName -Recurse -Force; Write-Host "[PRUNE]  old backup $($d.Name)" -ForegroundColor DarkGray }
            catch { Write-Host "[WARN]   could not delete old backup $($d.Name): $_" -ForegroundColor Yellow }
        }
    }
    Write-Host "To undo:  powershell -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Rollback `"$script:BackupDir`"" -ForegroundColor Cyan
    if ($Link) { Write-Host "          (run it as administrator, so the old links can be re-made)" -ForegroundColor Cyan }
    Write-Host "Restart Claude Code (or run /reload-plugins) to pick everything up."
}
