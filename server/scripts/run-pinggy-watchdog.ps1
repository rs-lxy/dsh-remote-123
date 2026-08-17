# Hidden watchdog: keeps the Pinggy anonymous SSH reverse tunnel running.
# Pinggy free tunnels expire every ~60 minutes and get a new URL; this script
# restarts ssh, writes the latest URL to ~/.dsh/dsh-remote-url.txt and
# publishes it to the public gist used by the fixed /go redirect.
# Pure ASCII (PowerShell 5.1 safe).
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'lib-remote.ps1')

$ssh = Get-Ssh
if (-not $ssh) { exit 2 }

$port = Get-GatewayPort
$outLog = Join-Path (Get-LogDir) 'dsh-remote-pinggy.log'
$errLog = Join-Path (Get-LogDir) 'dsh-remote-pinggy.err.log'
$urlFile = Join-Path (Get-DshHome) 'dsh-remote-url.txt'
$publishedFile = Join-Path (Get-DshHome) 'dsh-remote-published.txt'
$stampFile = Join-Path (Get-DshHome) 'dsh-remote-publish-stamp.txt'
$gistId = 'c92d2c52be0ba0e5f15fb9705ebea014'

while ($true) {
    if (-not (Test-PinggyRunning)) {
        Start-Process -FilePath $ssh `
            -ArgumentList @(
                '-p', '443',
                '-o', 'StrictHostKeyChecking=accept-new',
                '-o', 'ServerAliveInterval=30',
                '-o', 'ServerAliveCountMax=3',
                '-o', 'ExitOnForwardFailure=yes',
                '-R', ("0:127.0.0.1:{0}" -f $port),
                'a.pinggy.io'
            ) `
            -RedirectStandardOutput $outLog `
            -RedirectStandardError $errLog `
            -WindowStyle Hidden | Out-Null
        Start-Sleep -Seconds 3
    }

    $text = Get-Content $outLog -Raw -ErrorAction SilentlyContinue
    $ms = [regex]::Matches($text, 'https://[a-z0-9.-]+\.(?:run\.pinggy-free\.link|free\.pinggy\.net)')
    if ($ms.Count -gt 0) {
        $latest = $ms[$ms.Count - 1].Value
        Set-Content $urlFile $latest -Encoding ASCII

        $published = (Get-Content $publishedFile -Raw -ErrorAction SilentlyContinue).Trim()
        if ($latest -ne $published) {
            $lastStamp = 0
            if (Test-Path $stampFile) {
                $lastRaw = (Get-Content $stampFile -Raw -ErrorAction SilentlyContinue).Trim()
                [long]::TryParse($lastRaw, [ref]$lastStamp) | Out-Null
            }
            $nowMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            if (($nowMs - $lastStamp) -gt 90000) {
                $tmp = Join-Path $env:TEMP 'dsh-remote-url.txt'
                Set-Content $tmp $latest -Encoding ASCII
                & gh gist edit $gistId -f dsh-remote-url.txt $tmp 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Set-Content $publishedFile $latest -Encoding ASCII
                    Set-Content $stampFile ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) -Encoding ASCII
                }
            }
        }
    }

    Start-Sleep -Seconds 8
}
