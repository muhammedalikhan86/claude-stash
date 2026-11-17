<#
.SYNOPSIS
    Opens every worker checkout named in the hub's .claude/hub.json, each signed in to Claude Code
    as the same account as the hub (plugin-orchestrator-hub skill).

.EXAMPLE
    ./launch-workers.ps1                       # every worker, the hub's account, hub.json's mode
.EXAMPLE
    ./launch-workers.ps1 -Only advisor,ps      # just these (components[].short or .name)
.EXAMPLE
    ./launch-workers.ps1 -Mode terminal -DryRun
.EXAMPLE
    ./launch-workers.ps1 -WhoAmI               # print the account this session runs as, and stop
.EXAMPLE
    ./launch-workers.ps1 -IncludeInHub         # also open the workers that live in the hub checkout
.EXAMPLE
    ./launch-workers.ps1 -PermissionMode bypassPermissions   # workers start in this mode (terminal only)
.EXAMPLE
    ./launch-workers.ps1 -Model opus -Effort high            # workers' model and effort (terminal only)

.NOTES
    Each worker opens through its checkout's launch script (hub.json launch.script, normally
    launch-as.ps1), which wraps the claude-account-switcher skill. A checkout without one is opened with
    the switcher directly. Workers that live in the hub checkout (inHubCheckout, or checkout ".") open
    only with -IncludeInHub, as a second session in the hub checkout; without it the script prints the
    command to open each one. The hub itself is never opened. A window that opens has not registered
    yet: it shows in ListAgents only once its trust or sign-in prompt is cleared.
#>
param(
    [string]   $HubRoot,
    [string]   $Account,
    [ValidateSet('vscode', 'terminal')]
    [string]   $Mode,
    [string[]] $Only,
    [switch]   $WhoAmI,
    [switch]   $IncludeInHub,
    # The workers' permission mode. Omitted: hub.json launch.permissionMode, unless that is "same-as-hub"
    # (the default), which the hub resolves by passing its own mode here.
    [string]   $PermissionMode,
    # The workers' model and reasoning effort (claude --model / --effort; terminal only). Omitted:
    # hub.json launch.model / launch.effort, else each account's settings.json decides.
    [string]   $Model,
    [ValidateSet('', 'low', 'medium', 'high', 'xhigh', 'max')]
    [string]   $Effort,
    [switch]   $DryRun
)

$ErrorActionPreference = 'Stop'

if (-not $HubRoot) {
    $HubRoot = (git rev-parse --show-toplevel 2>$null)
    if (-not $HubRoot) { throw 'Run this inside the hub checkout, or pass -HubRoot.' }
}
$HubRoot = [System.IO.Path]::GetFullPath($HubRoot)

$switcher = Join-Path $HOME '.claude\skills\claude-account-switcher\scripts\claude-accounts.ps1'
$registry = Join-Path $HOME '.claude-accounts\accounts.json'

function Get-CurrentAccount {
    if (-not (Test-Path $registry)) { return $null }
    $accts = @((Get-Content $registry -Raw | ConvertFrom-Json).accounts)
    $dir = $env:CLAUDE_CONFIG_DIR
    $norm = { param($p) if ($p) { [System.IO.Path]::GetFullPath($p).TrimEnd('\', '/').ToLowerInvariant() } }
    if ([string]::IsNullOrWhiteSpace($dir)) {
        $hit = $accts | Where-Object { -not $_.dir -or ((& $norm $_.dir) -eq (& $norm (Join-Path $HOME '.claude'))) } | Select-Object -First 1
    } else {
        $hit = $accts | Where-Object { $_.dir -and ((& $norm $_.dir) -eq (& $norm $dir)) } | Select-Object -First 1
    }
    if ($hit) { return $hit.name }
    return $null
}

if ($WhoAmI) {
    $me = Get-CurrentAccount
    if ($me) { Write-Output $me } else { Write-Output 'unknown (CLAUDE_CONFIG_DIR matches no account in the switcher registry)' }
    exit 0
}

$cfgPath = Join-Path $HubRoot '.claude\hub.json'
if (-not (Test-Path $cfgPath)) { throw "No hub config at $cfgPath. See the skill's references/config.md." }
$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json

if (-not $Account) { $Account = Get-CurrentAccount }
if (-not $Account) { throw 'Could not tell which account this session runs as. Pass -Account <name>.' }
if (-not $Mode) { $Mode = if ($cfg.launch -and $cfg.launch.mode) { $cfg.launch.mode } else { 'vscode' } }
if (-not $PermissionMode -and $cfg.launch -and $cfg.launch.permissionMode -and $cfg.launch.permissionMode -ne 'same-as-hub') {
    $PermissionMode = $cfg.launch.permissionMode
}
if ($PermissionMode -and $Mode -ne 'terminal') { Write-Warning "-PermissionMode applies only to terminal workers; VS Code workers take their mode from VS Code settings." }
if (-not $Model -and $cfg.launch -and $cfg.launch.model) { $Model = $cfg.launch.model }
if (-not $Effort -and $cfg.launch -and $cfg.launch.effort) { $Effort = $cfg.launch.effort }
if (($Model -or $Effort) -and $Mode -ne 'terminal') { Write-Warning "-Model and -Effort apply only to terminal workers; VS Code workers take them from the account's settings." }
$launchName = if ($cfg.launch -and $cfg.launch.script) { $cfg.launch.script } else { 'launch-as.ps1' }

$isInHub = { param($c) (-not $c.checkout) -or $c.checkout -eq '.' -or $c.inHubCheckout }
$workers = @($cfg.components)
if ($Only) {
    $want = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
    $workers = @($workers | Where-Object { $want -contains ([string]$_.short).ToLowerInvariant() -or $want -contains ([string]$_.name).ToLowerInvariant() })
    if (-not $workers) { throw "None of '$($Only -join ',')' is a worker in hub.json." }
}

$failed = 0
foreach ($w in $workers) {
    $label = if ($w.short) { $w.short } else { $w.name }
    $inHub = & $isInHub $w
    $dir = if ($inHub) { $HubRoot } else { [System.IO.Path]::GetFullPath((Join-Path $HubRoot $w.checkout)) }
    if ($inHub -and -not $IncludeInHub) {
        $cmd = "& '$(Join-Path $HubRoot $launchName)' $Account" + $(if ($Mode -eq 'terminal') { ' -Terminal' } else { '' })
        Write-Output "$label : in the hub checkout, not opened (add -IncludeInHub, or run: $cmd)"
        continue
    }
    if (-not (Test-Path $dir)) { Write-Warning "$label : checkout not found at $dir"; $failed++; continue }

    $launcher = Join-Path $dir $launchName
    # An older launch-as.ps1 has no -Terminal switch; for terminal mode go straight to the switcher.
    # An older launch-as.ps1 has no -PermissionMode either; then the switcher is called directly too.
    $launcherOk = (Test-Path $launcher) -and ($Mode -ne 'terminal' -or (Select-String -Path $launcher -Pattern '\[switch\]\s*\$Terminal' -Quiet)) -and
                  (-not $PermissionMode -or (Select-String -Path $launcher -Pattern 'PermissionMode' -Quiet)) -and
                  (-not ($Model -or $Effort) -or (Select-String -Path $launcher -Pattern '\$Effort' -Quiet))
    if ($launcherOk) {
        $args2 = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $launcher, $Account)
    } elseif (Test-Path $switcher) {
        $args2 = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $switcher, 'open', $Account, '-Project', $dir)
    } else {
        Write-Warning "$label : no $launchName in the checkout and no account switcher installed"; $failed++; continue
    }
    if ($Mode -eq 'terminal') {
        $args2 += '-Terminal'
        if ($PermissionMode) { $args2 += @('-PermissionMode', $PermissionMode) }
        if ($Model) { $args2 += @('-Model', $Model) }
        if ($Effort) { $args2 += @('-Effort', $Effort) }
    }

    if ($DryRun) { Write-Output "$label -> powershell.exe $($args2 -join ' ')"; continue }
    powershell.exe @args2
    if ($LASTEXITCODE -ne 0) { Write-Warning "$label : launcher exited $LASTEXITCODE"; $failed++ }
    else { Write-Output "$label : opened $dir as $Account ($Mode)" }
}
if (-not $DryRun) { Write-Output 'Opened windows register only after their trust or sign-in prompt is cleared.' }
exit $failed
