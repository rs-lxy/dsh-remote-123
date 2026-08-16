# Start the fixed serveo.net tunnel (foreground). Public URL is stable:
# https://<Subdomain>.serveo.net
# One-time prerequisite: register the SSH key at https://console.serveo.net
# (the key lives at ~/.ssh/dsh_serveo / dsh_serveo.pub).
# Pure ASCII (PowerShell 5.1 safe).
param(
    [string]$Subdomain = 'dshremote'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib-remote.ps1')

$ssh = Get-Ssh
$key = Get-ServeoKey
if (-not $ssh) { Write-Host 'OpenSSH client not found.'; exit 2 }
if (-not $key) { Write-Host 'SSH key not found: ~/.ssh/dsh_serveo'; exit 3 }

if (-not (Test-GatewayListening)) {
    Write-Host "WARNING: gateway not listening on port $(Get-GatewayPort). Start it first."
}

Write-Host ("serveo tunnel -> https://{0}.serveo.net  (Ctrl+C to stop)" -f $Subdomain)
& $ssh -i $key -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30 `
    -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes `
    -R ("{0}:80:127.0.0.1:{1}" -f $Subdomain, (Get-GatewayPort)) serveo.net
