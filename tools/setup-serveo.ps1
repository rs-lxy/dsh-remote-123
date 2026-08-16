# One-time setup for the fixed serveo.net tunnel.
# Generates ~/.ssh/dsh_serveo and prints the one-click registration link.
# Open the link, log in with GitHub/Google, and approve the key. Then run:
#   powershell -File server\scripts\start-serveo.ps1
#   (fixed URL: https://dshremote.serveo.net)
# Pure ASCII (PowerShell 5.1 safe).
$ErrorActionPreference = 'Stop'

$key = Join-Path $env:USERPROFILE '.ssh\dsh_serveo'
if (-not (Test-Path $key)) {
    ssh-keygen -t ed25519 -f $key -N '""' -C 'dsh-remote' | Out-Null
    Write-Host 'SSH key generated.'
}

$fp = (ssh-keygen -lf "$key.pub" -E sha256).Trim()
$hash = ($fp -split '\s+')[1]

Write-Host ''
Write-Host '========================================'
Write-Host '  Step 1 (one time): open this link on the PC browser and log in'
Write-Host '  with GitHub or Google, then approve the key:'
Write-Host ''
Write-Host ('  https://console.serveo.net/ssh/keys?add=' + [uri]::EscapeDataString($hash)) -ForegroundColor Cyan
Write-Host ''
Write-Host '  Step 2: after approving, run:'
Write-Host '    powershell -File server\scripts\start-serveo.ps1'
Write-Host ''
Write-Host '  Fixed phone URL: https://dshremote.serveo.net'
Write-Host '========================================'
