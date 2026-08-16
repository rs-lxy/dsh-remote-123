# Remove dsh-remote autostart tasks and stop running components.
# Pure ASCII (PowerShell 5.1 safe).
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'lib-remote.ps1')

Unregister-ScheduledTask -TaskName 'dsh-remote-gateway' -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName 'dsh-remote-localhostrun' -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName 'dsh-remote-serveo' -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName 'dsh-remote-cloudflared' -Confirm:$false -ErrorAction SilentlyContinue

# Only remove the dsh-web task if this project created it.
$dshTask = Get-ScheduledTask -TaskName 'dsh-web' -ErrorAction SilentlyContinue
if ($dshTask -and ($dshTask.Actions.Arguments -match 'autostart-dsh-web\.vbs')) {
    Unregister-ScheduledTask -TaskName 'dsh-web' -Confirm:$false -ErrorAction SilentlyContinue
}
Write-Host 'Autostart tasks removed.'

Stop-GatewayProcesses
Stop-LocalhostRunTunnel
Stop-ServeoTunnel
Stop-CloudflaredTunnel
Write-Host 'Gateway and tunnel processes stopped.'

Write-Host ''
Write-Host 'Note: dsh web itself was not touched. Tailscale serve (if enabled) is still'
Write-Host 'configured; turn it off with: tailscale serve --https=443 off'
