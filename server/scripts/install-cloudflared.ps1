# Download a portable cloudflared.exe into tools\bin (no admin, no installer).
# Uses the GitHub API asset endpoint, which works even when github.com
# download links are blocked. Idempotent. Pure ASCII (PowerShell 5.1 safe).
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$dir = Join-Path $repoRoot 'tools\bin'
$target = Join-Path $dir 'cloudflared.exe'

if ((Test-Path $target) -and -not $Force) {
    Write-Host "cloudflared already present: $target"
    & $target --version
    exit 0
}

New-Item -ItemType Directory -Force $dir | Out-Null
$headers = @{ 'User-Agent' = 'dsh-remote-bootstrap' }
$release = Invoke-RestMethod -Headers $headers -Uri 'https://api.github.com/repos/cloudflare/cloudflared/releases/latest'
$asset = $release.assets | Where-Object { $_.name -eq 'cloudflared-windows-amd64.exe' } | Select-Object -First 1
if (-not $asset) { throw 'cloudflared-windows-amd64.exe asset not found in the latest release' }

$tmp = "$target.download"
Write-Host "Downloading cloudflared $($release.tag_name) ($([math]::Round($asset.size/1MB,1)) MB)..."
Invoke-WebRequest -Headers @{ 'User-Agent' = 'dsh-remote-bootstrap'; 'Accept' = 'application/octet-stream' } `
    -Uri $asset.url -OutFile $tmp -MaximumRedirection 5 -TimeoutSec 600
Move-Item $tmp $target -Force
Write-Host "Saved: $target"
& $target --version
