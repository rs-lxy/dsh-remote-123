# Permanent Cloudflare tunnel with your own domain (URL never changes).
# Prereqs (one time):
#   1. A domain added to Cloudflare.
#   2. cloudflared installed:  winget install Cloudflare.cloudflared
#   3. Create a tunnel once:
#        cloudflared tunnel login
#        cloudflared tunnel create mydsh
#      Edit %USERPROFILE%\.cloudflared\config.yml like this:
#        tunnel: <tunnel-id printed above>
#        credentials-file: %USERPROFILE%\.cloudflared\<id>.json
#        ingress:
#          - hostname: mydsh.example.com
#            service: http://127.0.0.1:8082
#          - service: http_status:404
#   4. DNS: cloudflared tunnel route dns mydsh mydsh.example.com
# Then run this script every time (or add "cloudflared tunnel run mydsh" to autostart).
# Pure ASCII (PowerShell 5.1 safe).
param(
    [Parameter(Mandatory=$true)][string]$TunnelName
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib-remote.ps1')

$cf = Get-Cloudflared
if (-not $cf) {
    Write-Host 'cloudflared not found. Run: winget install Cloudflare.cloudflared'
    exit 2
}
if (-not (Test-GatewayListening)) {
    Write-Host "WARNING: gateway not listening on port $(Get-GatewayPort)."
    Write-Host 'Start it first: powershell -File server\scripts\start-gateway.ps1'
}

Write-Host "Running named tunnel '$TunnelName' (Ctrl+C to stop)..."
& $cf tunnel run $TunnelName 2>&1
