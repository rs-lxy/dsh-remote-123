# Tailscale path: permanent https://<machine>.<tailnet>.ts.net/ URL for dsh-remote.
# Requires Tailscale installed and logged in on BOTH PC and phone (same account).
# Pure ASCII (PowerShell 5.1 safe).
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib-remote.ps1')

$port = Get-GatewayPort
$ts = Get-Tailscale
if (-not $ts) {
    Write-Host 'Tailscale not found. Install it on the PC and the phone first:' -ForegroundColor Yellow
    Write-Host '  https://tailscale.com/download'
    Write-Host 'Then log in with the SAME account on both devices and run this script again.'
    exit 2
}

Write-Host 'Checking Tailscale status...'
& $ts status
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Tailscale is not running/logged in. Run "tailscale login" first.' -ForegroundColor Red
    exit 3
}

if (-not (Test-GatewayListening)) {
    Write-Host "WARNING: gateway not listening on 127.0.0.1:$port" -ForegroundColor Yellow
    Write-Host '         Start it first: powershell -File server\scripts\start-gateway.ps1'
}

Write-Host ("Configuring tailscale serve -> http://127.0.0.1:{0} ..." -f $port)
& $ts serve --bg $port
if ($LASTEXITCODE -ne 0) {
    Write-Host 'tailscale serve failed. If it asks for HTTPS enablement, open the printed' -ForegroundColor Red
    Write-Host 'login.tailscale.com/f/serve URL in a browser, click Enable, then re-run this script.'
    exit 4
}

Write-Host ''
Write-Host 'Serve status:'
& $ts serve status

$status = & $ts serve status
$url = $null
foreach ($line in $status) {
    if ($line -match '(https://[^\s]+)') {
        $url = $Matches[1]
        break
    }
}

Write-Host ''
Write-Host '========================================'
if ($url) {
    Write-Host '  PHONE URL :' $url -ForegroundColor Cyan
} else {
    Write-Host '  PHONE URL : https://<your-machine>.<your-tailnet>.ts.net/  (see status above)' -ForegroundColor Cyan
}
Write-Host '  USER      :' (Get-RemoteUser)
Write-Host '  PASSWORD  :' (Read-RemotePassword) -ForegroundColor Yellow
Write-Host ''
Write-Host '  iPhone : open PHONE URL in Safari (keep Tailscale app connected) -> login'
Write-Host '           -> Share -> Add to Home Screen'
Write-Host '  Android: same URL in either APK, keep Tailscale app connected'
Write-Host '  NOTE   : the URL never changes; tailscale serve persists across reboots.'
Write-Host '========================================'
