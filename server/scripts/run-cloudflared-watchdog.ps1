# Hidden watchdog: keeps the cloudflared quick tunnel running (restart on exit).
# Pure ASCII (PowerShell 5.1 safe). Started by start-cloudflared-hidden / autostart.
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'lib-remote.ps1')

$cf = Get-Cloudflared
if (-not $cf) {
    exit 2
}

$port = Get-GatewayPort
$pattern = 'tunnel\s+--url\s+http://127\.0\.0\.1:' + $port + '(?:\s|$)'
$outLog = Join-Path (Get-LogDir) 'dsh-remote-cloudflared.log'
$errLog = Join-Path (Get-LogDir) 'dsh-remote-cloudflared.err.log'

function Test-TunnelRunning {
    Get-CimInstance Win32_Process -Filter "Name='cloudflared.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match $pattern } |
        Select-Object -First 1 | ForEach-Object { $true }
}

while ($true) {
    if (-not (Test-TunnelRunning)) {
        Start-Process -FilePath $cf `
            -ArgumentList @('tunnel','--url',("http://127.0.0.1:{0}" -f $port)) `
            -RedirectStandardOutput $outLog `
            -RedirectStandardError $errLog `
            -WindowStyle Hidden | Out-Null
        Start-Sleep -Seconds 3
    }
    Start-Sleep -Seconds 8
}
