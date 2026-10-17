$ErrorActionPreference = 'Stop'

$script = Get-Content (Join-Path $PSScriptRoot '..\scripts\vdd-tasks-setup.ps1') -Raw
foreach ($required in '-AllowStartIfOnBatteries', '-DontStopIfGoingOnBatteries') {
    if (-not $script.Contains($required)) {
        throw "VDD scheduled tasks must include $required"
    }
}
if (-not $script.Contains("-GroupId 'S-1-5-32-544'")) {
    throw 'VDD tasks must use the interactive Administrators group so Battery Saver can start them'
}
if ($script.Contains('-LogonType ServiceAccount')) {
    throw 'ServiceAccount VDD tasks are queued while Windows Battery Saver is active'
}

Write-Output 'VDD task principal and settings allow streaming while Battery Saver is active'
