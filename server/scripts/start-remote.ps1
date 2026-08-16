# One-click: start gateway + localhost.run public HTTPS tunnel (both hidden)
# and print the phone URL. No account, no VPN app, no port forwarding.
# The free URL is random and changes if the SSH tunnel / PC restarts.
# Pure ASCII (PowerShell 5.1 safe).
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib-remote.ps1')

$port = Get-GatewayPort
$user = Get-RemoteUser
$ssh = Get-Ssh

Write-Host ''
Write-Host '===== DSH Remote one-click start (localhost.run) ====='

if (-not $ssh) {
    Write-Host 'OpenSSH client not found. Enable it once:' -ForegroundColor Red
    Write-Host '  PowerShell(admin): Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0'
    exit 2
}

# 1) gateway
if (Test-GatewayListening) {
    Write-Host "[1/3] gateway already listening on 127.0.0.1:$port"
} else {
    Write-Host "[1/3] starting gateway (hidden watchdog)..."
    Start-GatewayHidden | Out-Null
    if (-not (Wait-GatewayListening 20)) {
        Write-Host 'ERROR: gateway did not start. Check ~/.dsh/logs/dsh-remote-gateway.log' -ForegroundColor Red
        exit 1
    }
    Write-Host "      gateway OK on 127.0.0.1:$port"
}

# Read the password AFTER the gateway has (possibly) generated it.
$password = Read-RemotePassword

# 2) localhost.run SSH tunnel
if (Test-LocalhostRunRunning) {
    Write-Host '[2/3] localhost.run tunnel already running'
} else {
    Write-Host '[2/3] starting localhost.run tunnel (hidden watchdog)...'
    Start-LocalhostRunHidden | Out-Null
}

# 3) wait for the public URL
$url = Wait-LocalhostRunUrl 45
if (-not $url) {
    Write-Host 'ERROR: did not get a lhr.life URL in time. Check ~/.dsh/logs/dsh-remote-localhostrun.log' -ForegroundColor Red
    exit 3
}
Write-Host "[3/3] tunnel URL: $url" -ForegroundColor Green

Write-Host ''
Write-Host '========================================'
Write-Host '  PHONE URL :' $url -ForegroundColor Cyan
Write-Host '  USER      :' $user
Write-Host '  PASSWORD  :' $password -ForegroundColor Yellow
Write-Host ''
Write-Host '  iPhone: open PHONE URL in Safari -> login -> Share -> Add to Home Screen'
Write-Host '  Android: use the same URL in dsh-mobile-app APK (add /mobile at the end)'
Write-Host '  NOTE   : no VPN and no registration needed. The URL changes only when'
Write-Host '           this tunnel reconnects or the PC restarts; run this script'
Write-Host '           again to print the new URL. Use install-autostart.ps1 for'
Write-Host '           auto-start after reboot.'
Write-Host '========================================'
