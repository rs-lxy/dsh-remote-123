# Hidden watchdog: keeps the user's dsh web profile running on 127.0.0.1:3080.
# Restarts it on crash. Pure ASCII (PowerShell 5.1 safe).
param(
    [int]$Port = 3080,
    [string]$WorkDir = ''
)

$ErrorActionPreference = 'SilentlyContinue'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not $WorkDir) { $WorkDir = (Resolve-Path (Join-Path $repoRoot '..')).Path }
if ($env:DSH_WEB_WORKDIR) { $WorkDir = $env:DSH_WEB_WORKDIR }

$logDir = Join-Path $env:USERPROFILE '.dsh\logs'
New-Item -ItemType Directory -Force $logDir | Out-Null
$outLog = Join-Path $logDir 'dsh-web.log'
$errLog = Join-Path $logDir 'dsh-web.err.log'

$npmRoot = (& npm root -g 2>$null)
if ($npmRoot) { $npmRoot = $npmRoot.Trim() }
$bin = Join-Path $npmRoot '@deepseek-ai\dsh\lib\bin.js'
if (-not (Test-Path $bin)) {
    $bin = Join-Path "$env:APPDATA\npm\node_modules\@deepseek-ai\dsh\lib\bin.js"
}
if (-not (Test-Path $bin)) { exit 2 }

$node = (Get-Command node.exe -ErrorAction SilentlyContinue).Source
if (-not $node) { exit 3 }

while ($true) {
    $listening = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if (-not $listening) {
        Start-Process -FilePath $node `
            -ArgumentList ('"{0}" web' -f $bin) `
            -WorkingDirectory $WorkDir `
            -RedirectStandardOutput $outLog `
            -RedirectStandardError $errLog `
            -WindowStyle Hidden | Out-Null
        Start-Sleep -Seconds 3
    }
    Start-Sleep -Seconds 8
}
