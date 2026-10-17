$ErrorActionPreference = 'Stop'

$script = Get-Content (Join-Path $PSScriptRoot '..\scripts\vdd-tasks-setup.ps1') -Raw
$wrapper = Get-Content (Join-Path $PSScriptRoot '..\scripts\vdd-task-hidden.vbs') -Raw -ErrorAction SilentlyContinue
$installer = Get-Content (Join-Path $PSScriptRoot '..\EternalMonitor.iss') -Raw
foreach ($required in '-AllowStartIfOnBatteries', '-DontStopIfGoingOnBatteries') {
    if (-not $script.Contains($required)) {
        throw "VDD scheduled tasks must include $required"
    }
}
if (-not $script.Contains('wscript.exe') -or $script.Contains("New-ScheduledTaskAction -Execute 'powershell.exe'")) {
    throw 'VDD scheduled tasks must use the windowless script host instead of powershell.exe directly'
}
if (-not $wrapper -or -not $wrapper.Contains('.Run(command, 0, True)')) {
    throw 'The VDD task wrapper must launch PowerShell hidden and wait for its exit code'
}
if (-not $installer.Contains('vdd-task-hidden.vbs')) {
    throw 'The installer must deploy the windowless VDD task wrapper'
}
if (-not $script.Contains("-GroupId 'S-1-5-32-544'")) {
    throw 'VDD tasks must use the interactive Administrators group so Battery Saver can start them'
}
if ($script.Contains('-LogonType ServiceAccount')) {
    throw 'ServiceAccount VDD tasks are queued while Windows Battery Saver is active'
}

Write-Output 'VDD tasks are hidden and can stream while Battery Saver is active'
