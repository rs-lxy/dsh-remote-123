# Start the dsh web profile hidden with a crash-restart watchdog.
# Pure ASCII (PowerShell 5.1 safe).
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib-remote.ps1')

$script = Join-Path $PSScriptRoot 'run-dsh-web-watchdog.ps1'
$arg = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $script
$p = Start-Process -FilePath 'powershell.exe' -ArgumentList $arg -WindowStyle Hidden -PassThru
Write-Host ('dsh web watchdog started (pid {0}). Log: ~/.dsh/logs/dsh-web.log' -f $p.Id)
$deadline = (Get-Date).AddSeconds(30)
while ((Get-Date) -lt $deadline) {
    if (Get-NetTCPConnection -LocalPort 3080 -State Listen -ErrorAction SilentlyContinue) {
        Write-Host 'dsh web is listening on 3080.' -ForegroundColor Green
        exit 0
    }
    Start-Sleep -Seconds 1
}
Write-Host 'ERROR: dsh web did not come up. Check ~/.dsh/logs/dsh-web.err.log' -ForegroundColor Red
exit 1
