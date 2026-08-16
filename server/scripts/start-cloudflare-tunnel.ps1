# Start a cloudflared quick tunnel in THIS window (foreground). The public
# https://xxx.trycloudflare.com URL is printed by cloudflared itself.
# Pure ASCII (PowerShell 5.1 safe).
param(
    [switch]$AutoInstall
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib-remote.ps1')

$port = Get-GatewayPort
$cf = Get-Cloudflared

if (-not $cf) {
    Write-Host 'cloudflared not found.' -ForegroundColor Yellow
    if ($AutoInstall) {
        Write-Host 'installing via winget...'
        winget install --id Cloudflare.cloudflared --accept-source-agreements --accept-package-agreements
        $cf = Get-Cloudflared
    }
    if (-not $cf) {
        Write-Host 'install it first:  winget install Cloudflare.cloudflared'
        exit 2
    }
}

if (-not (Test-GatewayListening)) {
    Write-Host "WARNING: gateway not listening on 127.0.0.1:$port. Start it first:" -ForegroundColor Yellow
    Write-Host '         powershell -File server\scripts\start-gateway.ps1'
    Write-Host '         (tunnel will be created anyway; it will fail until the gateway is up)'
}

Write-Host ('cloudflared quick tunnel -> http://127.0.0.1:{0}  (Ctrl+C to stop)' -f $port)
& $cf tunnel --url ("http://127.0.0.1:{0}" -f $port) 2>&1
