# Start the dsh-remote gateway in this window (foreground, logs to console).
# Pure ASCII (PowerShell 5.1 safe).
$ErrorActionPreference = 'Stop'
$server = Split-Path -Parent $PSScriptRoot
$node = (Get-Command node.exe -ErrorAction Stop).Source

Write-Host 'dsh-remote gateway starting... (press Ctrl+C to stop)'
Write-Host ('default upstream: http://127.0.0.1:3080 ; default port: 8082')
Write-Host 'override with DSH_REMOTE_UPSTREAM / DSH_REMOTE_PORT environment variables'
Push-Location $server
try {
    & $node 'gateway.mjs'
} finally {
    Pop-Location
}
