# Dot-sourced by install.ps1 and scripts/link-accounts.ps1. Works in Windows PowerShell 5.1 and pwsh 7.
#
# Get-MissingSettings <source json text> <target json text>
#   Lists what the source has that the target lacks: a key the target does not have, or an array item
#   (compared as compact JSON) the target's array does not hold. A key both have with a different
#   value is NOT listed: the target's own value is a choice, not a gap. Returns @() when nothing is
#   missing, so the caller writes no settings.stash.json.

function Get-MissingSettings([string]$SourceText, [string]$TargetText) {
    $src = $SourceText | ConvertFrom-Json
    $dst = $TargetText | ConvertFrom-Json
    $out = New-Object System.Collections.Generic.List[string]
    Compare-SettingsNode $src $dst '' $out
    return $out.ToArray()   # callers wrap the call in @(), so none or one item still counts right
}

function Compare-SettingsNode($Src, $Dst, [string]$Path, $Out) {
    foreach ($p in $Src.PSObject.Properties) {
        $q = if ($Path) { "$Path.$($p.Name)" } else { $p.Name }
        $have = $null -ne $Dst -and $Dst.PSObject.Properties.Name -contains $p.Name
        if (-not $have) { $Out.Add($q); continue }
        $sv = $p.Value; $dv = $Dst.($p.Name)
        if ($sv -is [System.Management.Automation.PSCustomObject]) {
            if ($dv -is [System.Management.Automation.PSCustomObject]) { Compare-SettingsNode $sv $dv $q $Out }
        }
        elseif ($sv -is [array]) {
            $dset = @(@($dv) | ForEach-Object { ConvertTo-Json -InputObject $_ -Compress -Depth 30 })
            foreach ($item in $sv) {
                $s = ConvertTo-Json -InputObject $item -Compress -Depth 30
                if ($dset -notcontains $s) { $Out.Add("$q[] $s") }
            }
        }
    }
}
