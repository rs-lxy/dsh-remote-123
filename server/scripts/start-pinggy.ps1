# One-click: start gateway + Pinggy free public HTTPS tunnel (hidden) and print
# the phone URL. Pinggy anonymous tunnels expire every ~60 minutes and get a
# new URL; use the fixed go link or run this script again to get the current one.
# Pure ASCII (PowerShell 5.1 safe).
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib-remote.ps1')

$port = Get-GatewayPort
$user = Get-RemoteUser
$ssh = Get-Ssh
if (-not $ssh) {
    Write-Host 'OpenSSH client not found. Enable Windows OpenSSH Client first.' -ForegroundColor Red
    exit 2
}

if (Test-GatewayListening) {
    Write-Host "[1/3] gateway already listening on 127.0.0.1:$port"
} else {
    Write-Host "[1/3] starting gateway (hidden watchdog)..."
    Start-GatewayHidden | Out-Null
    if (-not (Wait-GatewayListening 20)) {
        Write-Host 'ERROR: gateway did not start.' -ForegroundColor Red
        exit 1
    }
}
$password = Read-RemotePassword

if (Test-PinggyRunning) {
    Write-Host '[2/3] Pinggy tunnel already running'
} else {
    Write-Host '[2/3] starting Pinggy tunnel (hidden watchdog)...'
    Start-PinggyHidden | Out-Null
}

$url = Wait-PinggyUrl 60
if (-not $url) {
    Write-Host 'ERROR: did not get a Pinggy URL. Check ~/.dsh/logs/dsh-remote-pinggy.log' -ForegroundColor Red
    exit 3
}
Write-Host "[3/3] tunnel URL: $url" -ForegroundColor Green
Write-Host ''
Write-Host '========================================'
Write-Host '  FIXED GO LINK : https://rs-lxy.github.io/dsh-remote-123/go/' -ForegroundColor Green
Write-Host '  PHONE URL     :' $url -ForegroundColor Cyan
Write-Host '  USER          :' $user
Write-Host '  PASSWORD      :' $password -ForegroundColor Yellow
Write-Host '  NOTE          : free Pinggy URL changes about every 60 minutes;'
Write-Host '                  the GO LINK always jumps to the latest one.'
Write-Host '========================================'
