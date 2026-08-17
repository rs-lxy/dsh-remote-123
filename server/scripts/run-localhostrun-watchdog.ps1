# Hidden watchdog: keeps the localhost.run SSH reverse tunnel running.
# Public URL: https://<random>.lhr.life (HTTPS termination at localhost.run).
# Restarts ssh automatically and logs the new URL to
# ~/.dsh/logs/dsh-remote-localhostrun.log
# Pure ASCII (PowerShell 5.1 safe).
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'lib-remote.ps1')

$ssh = Get-Ssh
if (-not $ssh) { exit 2 }

$port = Get-GatewayPort
$outLog = Join-Path (Get-LogDir) 'dsh-remote-localhostrun.log'
$errLog = Join-Path (Get-LogDir) 'dsh-remote-localhostrun.err.log'
$urlFile = Join-Path (Get-DshHome) 'dsh-remote-url.txt'
$publishedFile = Join-Path (Get-DshHome) 'dsh-remote-published.txt'
$stampFile = Join-Path (Get-DshHome) 'dsh-remote-publish-stamp.txt'
$gistId = 'c92d2c52be0ba0e5f15fb9705ebea014'

while ($true) {
    if (-not (Test-LocalhostRunRunning)) {
        Start-Process -FilePath $ssh `
            -ArgumentList @(
                '-o', 'StrictHostKeyChecking=accept-new',
                '-o', 'ServerAliveInterval=30',
                '-o', 'ServerAliveCountMax=3',
                '-o', 'ExitOnForwardFailure=yes',
                '-R', ("80:127.0.0.1:{0}" -f $port),
                'nokey@localhost.run'
            ) `
            -RedirectStandardOutput $outLog `
            -RedirectStandardError $errLog `
            -WindowStyle Hidden | Out-Null
        Start-Sleep -Seconds 3
    }

    # Always publish the LATEST url from the log: localhost.run can mint a
    # new hostname while the ssh process stays alive, so this must run every
    # loop, not only right after starting ssh.
    $text = Get-Content $outLog -Raw -ErrorAction SilentlyContinue
    $ms = [regex]::Matches($text, 'https://[a-z0-9-]+\.lhr\.life')
    if ($ms.Count -gt 0) {
        $latest = $ms[$ms.Count - 1].Value
        Set-Content $urlFile $latest -Encoding ASCII

        # Publish the latest URL to a public gist (throttled to once per 90s).
        # The fixed GitHub Pages launcher /go redirects using this gist.
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
