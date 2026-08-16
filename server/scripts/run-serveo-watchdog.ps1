# Hidden watchdog: keeps the serveo.net fixed-subdomain tunnel running.
# Requires the SSH public key ~/.ssh/dsh_serveo.pub to be registered at
# https://console.serveo.net (free, GitHub/Google login).
# Public URL: https://<Subdomain>.serveo.net (stable across reconnects).
# Pure ASCII (PowerShell 5.1 safe).
param(
    [string]$Subdomain = 'dshremote'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'lib-remote.ps1')

$ssh = Get-Ssh
if (-not $ssh) { exit 2 }
$key = Get-ServeoKey
if (-not $key) { exit 3 }

$port = Get-GatewayPort
$outLog = Join-Path (Get-LogDir) 'dsh-remote-serveo.log'
$errLog = Join-Path (Get-LogDir) 'dsh-remote-serveo.err.log'
$urlFile = Join-Path (Get-DshHome) 'dsh-remote-url.txt'

while ($true) {
    if (-not (Test-ServeoRunning)) {
        Start-Process -FilePath $ssh `
            -ArgumentList @(
                '-i', $key,
                '-o', 'StrictHostKeyChecking=accept-new',
                '-o', 'ServerAliveInterval=30',
                '-o', 'ServerAliveCountMax=3',
                '-o', 'ExitOnForwardFailure=yes',
                '-R', ("{0}:80:127.0.0.1:{1}" -f $Subdomain, $port),
                'serveo.net'
            ) `
            -RedirectStandardOutput $outLog `
            -RedirectStandardError $errLog `
            -WindowStyle Hidden | Out-Null
        Start-Sleep -Seconds 3
    }

    $text = Get-Content $outLog -Raw -ErrorAction SilentlyContinue
    if ($text -match 'https://[a-z0-9.-]+\.serveo\.net') {
        Set-Content $urlFile $Matches[0] -Encoding ASCII
    } elseif ($text -match 'serveousercontent\.com') {
        Set-Content $urlFile $Matches[0] -Encoding ASCII
    }

    Start-Sleep -Seconds 8
}
