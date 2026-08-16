# Register autostart scheduled tasks for dsh-remote:
#   dsh-web + dsh-remote-gateway + dsh-remote-localhostrun
# Runs hidden at user logon. Cloudflare quick tunnel is optional and off by
# default (trycloudflare.com is filtered on some CN networks).
# Pure ASCII (PowerShell 5.1 safe).
param(
    [switch]$IncludeCloudflare,
    [switch]$Serveo
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib-remote.ps1')

$gatewayVbs = Join-Path $PSScriptRoot 'autostart-gateway.vbs'
$lhrVbs = Join-Path $PSScriptRoot 'autostart-localhostrun.vbs'
$serveoVbs = Join-Path $PSScriptRoot 'autostart-serveo.vbs'
$cfVbs = Join-Path $PSScriptRoot 'autostart-cloudflared.vbs'
$dshVbs = Join-Path $PSScriptRoot 'autostart-dsh-web.vbs'

$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero)
$trigger = New-ScheduledTaskTrigger -AtLogOn

if (Get-ScheduledTask -TaskName 'dsh-web' -ErrorAction SilentlyContinue) {
    Write-Host 'Task dsh-web already exists: keeping it unchanged.'
} else {
    Write-Host 'Registering dsh-web...'
    $actionDsh = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"{0}"' -f $dshVbs)
    Register-ScheduledTask -TaskName 'dsh-web' -Action $actionDsh -Trigger $trigger -Settings $settings -Force | Out-Null
}

Write-Host 'Registering dsh-remote-gateway...'
$action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"{0}"' -f $gatewayVbs)
Register-ScheduledTask -TaskName 'dsh-remote-gateway' -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null

if (Get-Ssh) {
    Write-Host 'Registering dsh-remote-localhostrun...'
    $actionLhr = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"{0}"' -f $lhrVbs)
    Register-ScheduledTask -TaskName 'dsh-remote-localhostrun' -Action $actionLhr -Trigger $trigger -Settings $settings -Force | Out-Null
} else {
    Write-Host 'OpenSSH client not found: skipping localhost.run task.' -ForegroundColor Yellow
}

if ($Serveo -and (Get-ServeoKey)) {
    Write-Host 'Registering dsh-remote-serveo (fixed https://dshremote.serveo.net)...'
    $actionServeo = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"{0}"' -f $serveoVbs)
    Register-ScheduledTask -TaskName 'dsh-remote-serveo' -Action $actionServeo -Trigger $trigger -Settings $settings -Force | Out-Null
} elseif ($Serveo) {
    Write-Host 'Serveo SSH key not found: run tools\setup-serveo.ps1 first.' -ForegroundColor Yellow
}

if ($IncludeCloudflare -and (Get-Cloudflared)) {
    Write-Host 'Registering dsh-remote-cloudflared...'
    $action2 = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"{0}"' -f $cfVbs)
    Register-ScheduledTask -TaskName 'dsh-remote-cloudflared' -Action $action2 -Trigger $trigger -Settings $settings -Force | Out-Null
} elseif ($IncludeCloudflare) {
    Write-Host 'cloudflared not found: run server\scripts\install-cloudflared.ps1 first.' -ForegroundColor Yellow
}

Write-Host 'Starting the tasks now...'
schtasks /run /tn dsh-web | Out-Null
schtasks /run /tn dsh-remote-gateway | Out-Null
if (Get-Ssh) { schtasks /run /tn dsh-remote-localhostrun | Out-Null }
if ($Serveo -and (Get-ServeoKey)) { schtasks /run /tn dsh-remote-serveo | Out-Null }
if ($IncludeCloudflare -and (Get-Cloudflared)) { schtasks /run /tn dsh-remote-cloudflared | Out-Null }

Write-Host ''
Write-Host 'Done. On next logon dsh-remote starts automatically (no window).' -ForegroundColor Green
Write-Host 'Current phone URL: run server\scripts\start-remote.ps1 to print it.'
Write-Host 'Logs: ~/.dsh/logs/dsh-remote-gateway.log and dsh-remote-localhostrun.log'
