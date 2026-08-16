# Hidden watchdog: keeps dsh-remote gateway.mjs running (restart on crash).
# Pure ASCII (PowerShell 5.1 safe). Started by start-gateway-hidden / autostart.
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'lib-remote.ps1')

$server = Split-Path -Parent $PSScriptRoot
$node = (Get-Command node.exe -ErrorAction Stop).Source
$port = Get-GatewayPort
$outLog = Join-Path (Get-LogDir) 'dsh-remote-gateway.log'
$errLog = Join-Path (Get-LogDir) 'dsh-remote-gateway.err.log'

while ($true) {
    if (-not (Test-GatewayListening)) {
        Start-Process -FilePath $node `
            -ArgumentList 'gateway.mjs' `
            -WorkingDirectory $server `
            -RedirectStandardOutput $outLog `
            -RedirectStandardError $errLog `
            -WindowStyle Hidden | Out-Null
        Start-Sleep -Seconds 3
    }
    Start-Sleep -Seconds 8
}
