<#
.SYNOPSIS
    Opens this checkout in a new VS Code window (or, with -Terminal, a terminal window) signed in
    to Claude Code as the given account.

.EXAMPLE
    ./launch-as lachlan

.EXAMPLE
    ./launch-as lachlan -Terminal                                   # bypass permissions (the default)

.EXAMPLE
    ./launch-as lachlan -Terminal -Permission Bypass               # or Auto, Manual, AcceptEdits, Plan, ...

.EXAMPLE
    ./launch-as lachlan -Terminal -Model opus -Effort high

.NOTES
    A thin wrapper over the claude-account-switcher skill's script. The account must already be
    set up there (run its "list" to see them). The window opens on the folder this file sits in.
    -Permission, -Model and -Effort go to Claude Code on the command line, so they win over every
    settings file (a global defaultMode "auto" would otherwise beat a project's bypass). They apply
    only with -Terminal; VS Code takes them from its own settings. -Permission defaults to
    ByPassPermissions; -Model and -Effort omitted: the settings decide.
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $Account,

    # Open Claude Code in a terminal window instead of VS Code.
    [switch] $Terminal,

    # The permission mode the session starts in. Case does not matter; "Bypass" is short for
    # ByPassPermissions. Default: ByPassPermissions.
    [Alias('PermissionMode')]
    [ValidateSet('ByPassPermissions', 'Bypass', 'Auto', 'Manual', 'Default', 'AcceptEdits', 'Plan', 'DontAsk')]
    [string] $Permission = 'ByPassPermissions',

    # The model and reasoning effort the session starts with (e.g. -Model opus -Effort high).
    [string] $Model,
    [ValidateSet('', 'low', 'medium', 'high', 'xhigh', 'max')]
    [string] $Effort
)

$switcher = Join-Path $HOME '.claude\skills\claude-account-switcher\scripts\claude-accounts.ps1'
if (-not (Test-Path $switcher)) {
    Write-Error "Account switcher not found at $switcher. Install the claude-account-switcher skill first."
    exit 1
}

# The exact spelling Claude Code's --permission-mode expects.
$mode = switch ($Permission) {
    { $_ -in 'ByPassPermissions', 'Bypass' } { 'bypassPermissions' }
    'Auto'        { 'auto' }
    'Manual'      { 'manual' }
    'Default'     { 'default' }
    'AcceptEdits' { 'acceptEdits' }
    'Plan'        { 'plan' }
    'DontAsk'     { 'dontAsk' }
}

$switcherArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $switcher, 'open', $Account, '-Project', $PSScriptRoot)
if ($Terminal) { $switcherArgs += @('-Terminal', '-PermissionMode', $mode) }
elseif ($PSBoundParameters.ContainsKey('Permission')) {
    Write-Warning "-Permission applies only with -Terminal; VS Code takes its mode from its own settings."
}
if ($Model) { $switcherArgs += @('-Model', $Model) }
if ($Effort) { $switcherArgs += @('-Effort', $Effort) }
powershell.exe @switcherArgs
exit $LASTEXITCODE
