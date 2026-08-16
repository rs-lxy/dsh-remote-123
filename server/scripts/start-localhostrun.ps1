# Start the localhost.run SSH reverse tunnel in THIS window (foreground).
# The public https://xxxx.lhr.life URL is printed by the service itself.
# Pure ASCII (PowerShell 5.1 safe).
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib-remote.ps1')

$port = Get-GatewayPort
$ssh = Get-Ssh
if (-not $ssh) {
    Write-Host 'OpenSSH client not found. Enable it once:' -ForegroundColor Red
    Write-Host '  PowerShell(admin): Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0'
    exit 2
}

if (-not (Test-GatewayListening)) {
    Write-Host "WARNING: gateway not listening on 127.0.0.1:$port. Start it first:" -ForegroundColor Yellow
    Write-Host '         powershell -File server\scripts\start-gateway.ps1'
}

Write-Host 'localhost.run tunnel -> gateway port ' $port ' (Ctrl+C to stop)'
& $ssh -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30 -o ServerAliveCountMax=3 `
    -o ExitOnForwardFailure=yes -R ("80:127.0.0.1:{0}" -f $port) nokey@localhost.run
