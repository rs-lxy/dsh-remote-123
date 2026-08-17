# Stop dsh-remote gateway + localhost.run tunnel + (optional) cloudflared.
# Keeps dsh web untouched. Pure ASCII (PowerShell 5.1 safe).
param(
    [switch]$TailscaleOff,
    [switch]$CloudflareToo
)
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'lib-remote.ps1')

Stop-GatewayProcesses
Stop-LocalhostRunTunnel
Stop-PinggyTunnel
Stop-ServeoTunnel
if ($CloudflareToo) { Stop-CloudflaredTunnel }
Write-Host 'dsh-remote gateway and tunnels stopped (dsh web untouched).'

if ($TailscaleOff) {
    $ts = Get-Tailscale
    if ($ts) {
        & $ts serve --https=443 off
        Write-Host 'tailscale serve turned off.'
    } else {
        Write-Host 'tailscale.exe not found; serve was not changed.'
    }
}
