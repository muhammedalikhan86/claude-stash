<#
.SYNOPSIS
  Manage multiple Claude Code accounts on Windows using CLAUDE_CONFIG_DIR.

.DESCRIPTION
  Each account gets its own config folder (credentials, settings, history).
  The script keeps a small registry at ~/.claude-accounts/accounts.json and
  writes a managed block of shortcut functions into the PowerShell profiles
  (Windows PowerShell 5.1 and PowerShell 7), for example:

    claude-work      start Claude Code as the "work" account
    code-work        open VS Code so the Claude extension uses "work"
    claude-default   start Claude Code with the normal ~/.claude folder

  The script never reads or prints credential contents.

.EXAMPLE
  .\claude-accounts.ps1 add work
  .\claude-accounts.ps1 add neeraj -Current      # the login already in ~/.claude
  .\claude-accounts.ps1 add client-a -Path D:\claude\client-a
  .\claude-accounts.ps1 list
  .\claude-accounts.ps1 status
  .\claude-accounts.ps1 remove work            # keeps the folder
  .\claude-accounts.ps1 remove work -DeleteData
  .\claude-accounts.ps1 install                # rewrite the profile block
  .\claude-accounts.ps1 open lachlan                       # new VS Code window as lachlan
  .\claude-accounts.ps1 open john -Project C:\code\app     # same, for a given folder
  .\claude-accounts.ps1 open john -Terminal                 # terminal instead of VS Code
  .\claude-accounts.ps1 open john -Terminal -PermissionMode bypassPermissions
  .\claude-accounts.ps1 open john -Terminal -Model opus -Effort high
  .\claude-accounts.ps1 sync                               # copy this skill to every account
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('list', 'add', 'remove', 'status', 'install', 'open', 'sync')]
    [string]$Command = 'list',

    [Parameter(Position = 1)]
    [string]$Name,

    [string]$Path,

    # add: register this name as the login already in ~/.claude (no new folder or login)
    [switch]$Current,

    [switch]$DeleteData,

    # open: project folder to start in (defaults to the current folder)
    [string]$Project,

    # open: VS Code is the default; -VSCode is accepted for compatibility
    [switch]$VSCode,

    # open: start Claude Code in a terminal window instead of VS Code
    [switch]$Terminal,

    # open -Terminal: the permission mode the new Claude Code starts in (bypassPermissions maps to
    # --dangerously-skip-permissions). Not used for VS Code, which takes its mode from its own settings.
    [ValidateSet('', 'default', 'acceptEdits', 'auto', 'manual', 'dontAsk', 'plan', 'bypassPermissions')]
    [string]$PermissionMode = '',

    # open -Terminal: the model (claude --model, e.g. opus or claude-opus-5-5) and reasoning effort
    # (claude --effort) the new Claude Code starts with. Omitted: the account's settings.json decides.
    [string]$Model = '',
    [ValidateSet('', 'low', 'medium', 'high', 'xhigh', 'max')]
    [string]$Effort = '',

    # open: print what would be launched without launching it
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
if ($Name) { $Name = $Name.Trim().ToLowerInvariant() }

$RegistryDir  = Join-Path $HOME '.claude-accounts'
$RegistryFile = Join-Path $RegistryDir 'accounts.json'
$DefaultDir   = Join-Path $HOME '.claude'
$BeginMarker  = '# >>> claude-accounts (managed by claude-account-switcher skill) >>>'
$EndMarker    = '# <<< claude-accounts <<<'

function Get-Accounts {
    if (-not (Test-Path $RegistryFile)) { return @() }
    $raw = Get-Content -Path $RegistryFile -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
    $data = $raw | ConvertFrom-Json
    if ($null -eq $data.accounts) { return @() }
    return @($data.accounts)
}

function Save-Accounts([object[]]$Accounts) {
    New-Item -ItemType Directory -Force -Path $RegistryDir | Out-Null
    $obj = [pscustomobject]@{ accounts = @($Accounts) }
    $obj | ConvertTo-Json -Depth 5 | Set-Content -Path $RegistryFile -Encoding UTF8
}

function Get-ProfilePaths {
    # CurrentUserAllHosts profiles, so the shortcuts work in Windows Terminal,
    # the VS Code terminal and any other PowerShell host.
    $docs = [Environment]::GetFolderPath('MyDocuments')
    if ([string]::IsNullOrWhiteSpace($docs)) { $docs = Join-Path $HOME 'Documents' }
    return @(
        (Join-Path $docs 'WindowsPowerShell\profile.ps1'),
        (Join-Path $docs 'PowerShell\profile.ps1')
    )
}

function Quote([string]$s) { "'" + ($s -replace "'", "''") + "'" }

function Test-IsDefaultDir([string]$Dir) {
    if ([string]::IsNullOrWhiteSpace($Dir)) { return $true }
    return ($Dir.TrimEnd('\', '/') -eq $DefaultDir.TrimEnd('\', '/'))
}

function Get-DefaultOwner {
    return (Get-Accounts | Where-Object { Test-IsDefaultDir $_.dir } | Select-Object -First 1)
}

function Get-AccountEmail([string]$Dir) {
    # Best effort: reads only the signed-in email from Claude Code's state file,
    # never tokens. ~/.claude.json for the default folder, <dir>/.claude.json otherwise.
    $file = if (Test-IsDefaultDir $Dir) { Join-Path $HOME '.claude.json' } else { Join-Path $Dir '.claude.json' }
    if (-not (Test-Path $file)) { return '' }
    try {
        $j = Get-Content -Path $file -Raw | ConvertFrom-Json
        if ($j.oauthAccount -and $j.oauthAccount.emailAddress) { return [string]$j.oauthAccount.emailAddress }
    } catch { }
    return ''
}

function Test-LoggedIn([string]$Dir) {
    # Presence check only; contents are never read.
    return (Test-Path (Join-Path $Dir '.credentials.json'))
}

function Build-Block([object[]]$Accounts) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add($BeginMarker)
    $lines.Add('# Do not edit by hand: run claude-accounts.ps1 to change this block.')
    $lines.Add('function Invoke-ClaudeAccount([string]$Dir, [string]$Exe, [object[]]$Rest) {')
    $lines.Add('    $prev = $env:CLAUDE_CONFIG_DIR')
    $lines.Add('    try {')
    $lines.Add('        if ($Dir) { $env:CLAUDE_CONFIG_DIR = $Dir } else { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue }')
    $lines.Add('        & $Exe @Rest')
    $lines.Add('    } finally {')
    $lines.Add('        if ($null -ne $prev) { $env:CLAUDE_CONFIG_DIR = $prev } else { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue }')
    $lines.Add('    }')
    $lines.Add('}')
    $self  = Quote $PSCommandPath
    $shell = Quote ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
    $lines.Add('function Open-ClaudeVSCode([string]$Name, [object[]]$Rest) {')
    $lines.Add('    $proj = if ($Rest -and $Rest.Count -gt 0) { [string]$Rest[0] } else { (Get-Location).Path }')
    $lines.Add("    if (-not (Test-Path $self)) { Write-Error 'claude-accounts.ps1 has moved; run its install command again.'; return }")
    $lines.Add("    & $shell -NoProfile -ExecutionPolicy Bypass -File $self open `$Name -Project `$proj")
    $lines.Add('}')
    $lines.Add("function claude-default { Invoke-ClaudeAccount '' 'claude' `$args }")
    $lines.Add("function code-default { Open-ClaudeVSCode 'default' `$args }")
    foreach ($a in $Accounts) {
        # The original login must run with CLAUDE_CONFIG_DIR unset, because
        # Claude Code keeps part of its state in ~/.claude.json in that mode.
        $d = if (Test-IsDefaultDir $a.dir) { "''" } else { Quote $a.dir }
        $lines.Add("function claude-$($a.name) { Invoke-ClaudeAccount $d 'claude' `$args }")
        $lines.Add("function code-$($a.name) { Open-ClaudeVSCode '$($a.name)' `$args }")
    }
    $lines.Add($EndMarker)
    return ($lines -join "`r`n")
}

function Install-Block {
    $block = Build-Block (Get-Accounts)
    $pattern = '(?s)' + [regex]::Escape($BeginMarker) + '.*?' + [regex]::Escape($EndMarker) + '(\r?\n)?'
    foreach ($p in Get-ProfilePaths) {
        New-Item -ItemType Directory -Force -Path (Split-Path $p) | Out-Null
        $content = ''
        if (Test-Path $p) {
            $content = Get-Content -Path $p -Raw
            if ($null -eq $content) { $content = '' }
        }
        $content = [regex]::Replace($content, $pattern, '').TrimEnd()
        if ($content.Length -gt 0) { $content += "`r`n`r`n" }
        $content += $block + "`r`n"
        Set-Content -Path $p -Value $content -Encoding UTF8 -NoNewline
        Write-Host "Updated profile: $p"
    }
}

function Assert-Name([string]$n) {
    if ([string]::IsNullOrWhiteSpace($n)) { throw 'An account name is required, e.g. "work".' }
    if ($n -cnotmatch '^[a-z0-9][a-z0-9-]{0,31}$') {
        throw "Invalid name '$n'. Use lowercase letters, digits and hyphens (max 32 chars), e.g. work, personal, client-a."
    }
    if ($n -eq 'default') { throw "'default' is reserved for the normal ~/.claude folder." }
}

function Show-List {
    $accounts = Get-Accounts
    $owner = Get-DefaultOwner
    $fmt = "{0,-16} {1,-14} {2,-32} {3}"
    Write-Host ($fmt -f 'ACCOUNT', 'STATUS', 'EMAIL', 'FOLDER')
    if (-not $owner) {
        $def = if (Test-LoggedIn $DefaultDir) { 'logged in' } else { 'not logged in' }
        Write-Host ($fmt -f 'default', $def, (Get-AccountEmail $DefaultDir), "$DefaultDir (original login)")
    }
    foreach ($a in $accounts) {
        $s = if (Test-LoggedIn $a.dir) { 'logged in' } else { 'not logged in' }
        $folder = if (Test-IsDefaultDir $a.dir) { "$DefaultDir (original login)" } else { $a.dir }
        Write-Host ($fmt -f $a.name, $s, (Get-AccountEmail $a.dir), $folder)
    }
    if ($accounts.Count -eq 0) { Write-Host "`nNo extra accounts yet. Add one with: claude-accounts.ps1 add <name>" }
}

function Resolve-Account([string]$n) {
    # Returns @{ name; dir } where dir is '' for the default account.
    if ([string]::IsNullOrWhiteSpace($n)) { throw 'Say which account to open, e.g. open work.' }
    if ($n -eq 'default') {
        $o = Get-DefaultOwner
        $label = if ($o) { $o.name } else { 'default' }
        return @{ name = $label; dir = '' }
    }
    $a = Get-Accounts | Where-Object { $_.name -eq $n } | Select-Object -First 1
    if (-not $a) {
        $known = (@(Get-Accounts | ForEach-Object { $_.name }) + @('default')) -join ', '
        throw "No account named '$n'. Known accounts: $known"
    }
    $d = if (Test-IsDefaultDir $a.dir) { '' } else { $a.dir }
    return @{ name = $a.name; dir = $d }
}

function Find-Code {
    foreach ($c in @('code.cmd', 'code')) {
        $cmd = Get-Command $c -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd) { return $cmd.Source }
    }
    $candidates = @()
    if ($env:LOCALAPPDATA) { $candidates += Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd' }
    if ($env:ProgramFiles) { $candidates += Join-Path $env:ProgramFiles 'Microsoft VS Code\bin\code.cmd' }
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    throw 'Could not find VS Code (the "code" command). In VS Code run "Shell Command: Install code command in PATH", or reinstall VS Code with "Add to PATH" ticked.'
}

function Initialize-VSCodeData([string]$UserDataDir, [string]$Label) {
    # Each account gets its own VS Code user-data folder. That makes VS Code start
    # a separate instance for it, which is what lets it carry its own account.
    # Extensions stay shared (they live in ~/.vscode/extensions).
    $userDir = Join-Path $UserDataDir 'User'
    New-Item -ItemType Directory -Force -Path $userDir | Out-Null
    $source = if ($env:APPDATA) { Join-Path $env:APPDATA 'Code\User' } else { '' }
    if ($source -and (Test-Path $source)) {
        foreach ($f in @('settings.json', 'keybindings.json')) {
            $from = Join-Path $source $f; $to = Join-Path $userDir $f
            if ((Test-Path $from) -and -not (Test-Path $to)) { Copy-Item -Path $from -Destination $to }
        }
        $fromSnip = Join-Path $source 'snippets'; $toSnip = Join-Path $userDir 'snippets'
        if ((Test-Path $fromSnip) -and -not (Test-Path $toSnip)) { Copy-Item -Recurse -Path $fromSnip -Destination $toSnip }
    }
    # Put the account name in the window title so the windows are easy to tell apart.
    $settingsPath = Join-Path $userDir 'settings.json'
    $title = "[$Label] `${activeEditorShort}`${separator}`${rootName}"
    $settings = $null
    if (Test-Path $settingsPath) {
        try { $settings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json } catch { $settings = $null }
        if ($null -eq $settings) { return }   # unparseable (e.g. comments in 5.1): leave the copy as-is
    } else {
        $settings = [pscustomobject]@{}
    }
    if ($settings.'window.title' -eq $title) { return }
    $settings | Add-Member -NotePropertyName 'window.title' -NotePropertyValue $title -Force
    $settings | ConvertTo-Json -Depth 50 | Set-Content -Path $settingsPath -Encoding UTF8
}

# Variables a running Claude Code session sets for itself and its tools. A window opened from inside a
# session inherits them, and the new Claude Code then thinks it is a child session: no transcript, no
# peer messaging, not listed by ListAgents. CLAUDE_CONFIG_DIR is not one of them.
$SessionEnvPattern = '^(CLAUDECODE$|CLAUDE_CODE_|CLAUDE_PID$|CLAUDE_AGENT_SDK|CLAUDE_EFFORT$)'

# The same clean-up as a command for the new window: drop each inherited session variable, but keep a
# value set at User or Machine level (a deliberate setting, not an inherited one).
$CleanEnvCmd = '@(Get-ChildItem Env: | Where-Object Name -match ''' + $SessionEnvPattern + ''') | ForEach-Object { $n = $_.Name; Remove-Item -LiteralPath "Env:$n"; $v = [Environment]::GetEnvironmentVariable($n, ''User''); if (-not $v) { $v = [Environment]::GetEnvironmentVariable($n, ''Machine'') }; if ($v) { Set-Item -LiteralPath "Env:$n" -Value $v } }'

function Clear-SessionEnv {
    # Removes the inherited session variables from this process and returns them, for Restore-SessionEnv.
    $saved = @{}
    foreach ($v in @(Get-ChildItem Env: | Where-Object Name -match $SessionEnvPattern)) {
        $keep = [Environment]::GetEnvironmentVariable($v.Name, 'User')
        if (-not $keep) { $keep = [Environment]::GetEnvironmentVariable($v.Name, 'Machine') }
        if ($keep) { continue }
        $saved[$v.Name] = $v.Value
        Remove-Item -LiteralPath "Env:$($v.Name)"
    }
    return $saved
}

function Restore-SessionEnv([hashtable]$Saved) {
    foreach ($k in $Saved.Keys) { Set-Item -LiteralPath "Env:$k" -Value $Saved[$k] }
}

function Open-VSCode($acct, [string]$proj, [string]$label) {
    $code = Find-Code
    $codeArgs = @()
    if ($acct.dir) {
        $udd = Join-Path $RegistryDir "vscode\$($acct.name)"
        if (-not $DryRun) { Initialize-VSCodeData $udd $label }
        $codeArgs += @('--user-data-dir', "`"$udd`"")
    }
    # The original login uses your normal VS Code (no --user-data-dir).
    $codeArgs += @('--new-window', "`"$proj`"")
    if ($DryRun) {
        Write-Host "Would run: $code $($codeArgs -join ' ')"
        Write-Host "with CLAUDE_CONFIG_DIR=$(if ($acct.dir) { $acct.dir } else { '(unset: original login)' })"
        return
    }
    $prev = $env:CLAUDE_CONFIG_DIR
    $saved = Clear-SessionEnv
    try {
        if ($acct.dir) { $env:CLAUDE_CONFIG_DIR = $acct.dir } else { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue }
        Start-Process -FilePath $code -ArgumentList $codeArgs -WindowStyle Hidden
    } finally {
        if ($null -ne $prev) { $env:CLAUDE_CONFIG_DIR = $prev } else { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue }
        Restore-SessionEnv $saved
    }
    Write-Host "Opened a new VS Code window as '$($acct.name)' in $proj."
}

function Sync-Skill {
    # Copy this skill into every account's skills folder, so whichever account
    # Claude Code runs as, it uses the same (current) version of the skill.
    $skillDir = Split-Path -Parent $PSScriptRoot
    $skillName = Split-Path -Leaf $skillDir
    $targets = @($DefaultDir) + @(Get-Accounts | ForEach-Object { $_.dir })
    $done = @{}
    foreach ($t in $targets) {
        $key = $t.TrimEnd('\', '/').ToLowerInvariant()
        if ($done.ContainsKey($key)) { continue }
        $done[$key] = $true
        if (-not (Test-Path $t)) { continue }
        $dest = Join-Path (Join-Path $t 'skills') $skillName
        $srcFull = [System.IO.Path]::GetFullPath($skillDir).TrimEnd('\', '/')
        $dstFull = [System.IO.Path]::GetFullPath($dest).TrimEnd('\', '/')
        if ($srcFull -eq $dstFull) { continue }
        if (Test-Path $dest) { Remove-Item -Recurse -Force -Path $dest }
        New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
        Copy-Item -Recurse -Path $skillDir -Destination $dest
        Write-Host "Skill updated in: $dest"
    }
}

function Open-Account {
    $acct = Resolve-Account $Name
    $proj = if ($Project) { $Project } else { (Get-Location).Path }
    $proj = [System.IO.Path]::GetFullPath($proj)
    if (-not (Test-Path $proj)) { throw "Project folder not found: $proj" }
    $label = (Get-Culture).TextInfo.ToTitleCase($acct.name)
    $checkDir = if ($acct.dir) { $acct.dir } else { $DefaultDir }
    if (-not (Test-LoggedIn $checkDir)) {
        Write-Host "Note: '$($acct.name)' is not logged in yet; log in when Claude Code asks (or run /login)."
    }

    if (-not $Terminal) {
        if ($PermissionMode) { Write-Warning "-PermissionMode applies only with -Terminal; VS Code takes its mode from its own settings." }
        if ($Model -or $Effort) { Write-Warning "-Model and -Effort apply only with -Terminal; VS Code takes them from the account's settings." }
        Open-VSCode $acct $proj $label; return
    }

    # The account is set inside the new window's own command, so it is correct
    # even when Windows Terminal hands the window to an already-running instance.
    $envCmd = if ($acct.dir) { '$env:CLAUDE_CONFIG_DIR = ' + (Quote $acct.dir) } else { 'Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue' }
    # A window opened from inside a Claude Code session inherits that session's variables; clear them
    # first so the new session is a full one (transcript, peer messaging).
    $claudeCmd = switch ($PermissionMode) {
        ''                  { 'claude' }
        'bypassPermissions' { 'claude --dangerously-skip-permissions' }
        default             { "claude --permission-mode $PermissionMode" }
    }
    if ($Model)  { $claudeCmd += " --model $(Quote $Model)" }
    if ($Effort) { $claudeCmd += " --effort $Effort" }
    $inner = "$CleanEnvCmd; $envCmd; Set-Location -LiteralPath $(Quote $proj); `$Host.UI.RawUI.WindowTitle = $(Quote "Claude - $label"); $claudeCmd"
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($inner))
    $shell = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { 'pwsh.exe' } else { 'powershell.exe' }
    $wt = Get-Command wt.exe -ErrorAction SilentlyContinue

    if ($DryRun) {
        Write-Host "Shell: $shell  (Windows Terminal: $([bool]$wt))"
        Write-Host "Command in new window: $inner"
        Write-Host "Encoded: $encoded"
        return
    }
    if ($wt) {
        # wt.exe can hand the tab this process's environment; clear it here too, then put it back.
        $saved = Clear-SessionEnv
        try { Start-Process -FilePath 'wt.exe' -ArgumentList @('-w', 'new', 'new-tab', '--title', "`"Claude - $label`"", '-d', "`"$proj`"", $shell, '-NoExit', '-EncodedCommand', $encoded) }
        finally { Restore-SessionEnv $saved }
    } else {
        $saved = Clear-SessionEnv
        try { Start-Process -FilePath $shell -ArgumentList @('-NoExit', '-EncodedCommand', $encoded) }
        finally { Restore-SessionEnv $saved }
    }
    Write-Host "Opened a new window running Claude Code as '$($acct.name)' in $proj."
}

switch ($Command) {
    'list' { Show-List }

    'status' {
        $cur = $env:CLAUDE_CONFIG_DIR
        if ([string]::IsNullOrWhiteSpace($cur)) {
            $o = Get-DefaultOwner
            $label = if ($o) { $o.name } else { 'default' }
            Write-Host "CLAUDE_CONFIG_DIR is not set: this session uses the original login in $DefaultDir  ->  account: $label"
        } elseif (Test-IsDefaultDir $cur) {
            $o = Get-DefaultOwner
            $label = if ($o) { $o.name } else { 'default' }
            Write-Host "CLAUDE_CONFIG_DIR = $cur (the original login folder)  ->  account: $label"
        } else {
            $match = Get-Accounts | Where-Object { $_.dir -eq $cur } | Select-Object -First 1
            $label = if ($match) { $match.name } else { '(not a registered account)' }
            Write-Host "CLAUDE_CONFIG_DIR = $cur  ->  account: $label"
        }
        Write-Host ''
        Show-List
    }

    'add' {
        Assert-Name $Name
        $accounts = @(Get-Accounts)
        if ($accounts | Where-Object { $_.name -eq $Name }) { throw "Account '$Name' already exists." }
        if ($Current) {
            $o = Get-DefaultOwner
            if ($o) { throw "The original login is already registered as '$($o.name)'. Remove it first to reassign." }
            $accounts += [pscustomobject]@{ name = $Name; dir = $DefaultDir }
            Save-Accounts $accounts
            Install-Block
            Write-Host ''
            $email = Get-AccountEmail $DefaultDir
            $who = if ($email) { " ($email)" } else { '' }
            Sync-Skill
            if (Test-LoggedIn $DefaultDir) {
                Write-Host "Registered '$Name' as the current login$who. No new login needed."
            } else {
                Write-Host "Registered '$Name' as the original ~/.claude folder, but it is not logged in yet; log in the next time you open it."
            }
            break
        }
        $dir = if ($Path) { $Path } else { Join-Path $HOME ".claude-$Name" }
        $dir = [System.IO.Path]::GetFullPath($dir)
        if (Test-IsDefaultDir $dir) { throw 'That is the original login folder; use  add <name> -Current  to register it.' }
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $accounts += [pscustomobject]@{ name = $Name; dir = $dir }
        Save-Accounts $accounts
        Install-Block
        Sync-Skill
        Write-Host ''
        Write-Host "Added '$Name' -> $dir"
        Write-Host "Next: switch to it (e.g. code-$Name in PowerShell) and log in when Claude Code asks."
    }

    'remove' {
        Assert-Name $Name
        $accounts = @(Get-Accounts)
        $target = $accounts | Where-Object { $_.name -eq $Name } | Select-Object -First 1
        if (-not $target) { throw "No account named '$Name'." }
        Save-Accounts @($accounts | Where-Object { $_.name -ne $Name })
        Install-Block
        if ($DeleteData) {
            if (Test-IsDefaultDir $target.dir) { throw "Refusing to delete the original ~/.claude folder. '$Name' was unregistered; its login is untouched." }
            if (Test-Path $target.dir) { Remove-Item -Recurse -Force -Path $target.dir }
            Write-Host "Removed '$Name' and deleted $($target.dir)."
        } else {
            Write-Host "Removed '$Name'. Its folder was kept: $($target.dir)"
        }
    }

    'open' { Open-Account }

    'sync' { Sync-Skill }

    'install' {
        Install-Block
        Sync-Skill
        Write-Host 'Shortcuts rewritten. Open a new PowerShell window to use them.'
    }
}
