# Print the CURRENT phone URL(s) and password. Run any time after a tunnel
# reconnect / PC restart. Double-click show-url.bat for the same result.
# Pure ASCII (PowerShell 5.1 safe).
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'lib-remote.ps1')

Write-Host ''
Write-Host '===== DSH Remote current addresses ====='

$fixedFile = Join-Path (Get-DshHome) 'dsh-remote-fixed-url.txt'
if (Test-Path $fixedFile) {
    $fixed = (Get-Content $fixedFile -Raw -ErrorAction SilentlyContinue).Trim()
    if ($fixed) {
        Write-Host ('  FIXED PHONE URL (oray)    : ' + $fixed) -ForegroundColor Green
    }
}

$lhr = Wait-LocalhostRunUrl 2
if ($lhr) {
    Write-Host ('  PHONE URL (localhost.run): ' + $lhr) -ForegroundColor Cyan
} else {
    Write-Host '  localhost.run tunnel not running (fixed URL is primary).' -ForegroundColor Yellow
}

$cfLog = Join-Path (Get-LogDir) 'dsh-remote-cloudflared.err.log'
if (Test-Path $cfLog) {
    $cfText = Get-Content $cfLog -Raw -ErrorAction SilentlyContinue
    if ($cfText -match 'https://(?!api\.)[a-z0-9-]+\.trycloudflare\.com') {
        Write-Host ('  PHONE URL (cloudflared)  : ' + $Matches[0])
    }
}

$password = Read-RemotePassword
Write-Host ('  USER     : ' + (Get-RemoteUser))
Write-Host ('  PASSWORD : ' + $password) -ForegroundColor Yellow
Write-Host ''
Write-Host '  iPhone: open PHONE URL in Safari -> login -> Share -> Add to Home Screen'
Write-Host '  Android: same URL + /mobile in dsh-mobile-app APK'
Write-Host ''
