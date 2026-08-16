# Mount the mobile-fit plugin (joyfish666/deepseek-harness-remote, MIT) into
# the local dsh web profile. After a dsh web restart the phone gets the
# drawer navigation / full-screen settings / Enter-as-newline experience.
# Idempotent. Pure ASCII (PowerShell 5.1 safe).
param(
    [string]$DshHome = $env:DSH_HOME
)

$ErrorActionPreference = 'Stop'

if (-not $DshHome) { $DshHome = Join-Path $env:USERPROFILE '.dsh' }
if (-not $DshHome) { throw 'Cannot determine DSH_HOME' }

$profileDir = Join-Path $DshHome 'profiles\web'
$patchFile = Join-Path $profileDir 'cordis.patch.yml'
$nodeModules = Join-Path $profileDir 'node_modules'
$src = Join-Path $PSScriptRoot '..\mobile-fit'
if (Test-Path (Join-Path $src 'package.json')) {
    $src = (Resolve-Path $src).Path
} else {
    $src = Join-Path $PSScriptRoot 'mobile-fit'
}

if (-not (Test-Path (Join-Path $src 'package.json'))) {
    throw "mobile-fit plugin not found: $src"
}
if (-not (Test-Path $profileDir)) {
    throw "dsh web profile not found: $profileDir (run 'npx @deepseek-ai/dsh web' once first)"
}

Write-Host '==> Mounting mobile-fit plugin'
New-Item -ItemType Directory -Force $nodeModules | Out-Null
$target = Join-Path $nodeModules 'mobile-fit'

if ((Test-Path $target) -and -not (Test-Path (Join-Path $target 'lib\client.js'))) {
    Write-Host "    removing broken old mount: $target"
    Remove-Item $target -Recurse -Force
}

if (-not (Test-Path (Join-Path $target 'lib\client.js'))) {
    try {
        cmd /c mklink /J "$target" "$src" | Out-Null
    } catch {
        Write-Host '    junction failed, falling back to copy' -ForegroundColor Yellow
    }
}
if (-not (Test-Path (Join-Path $target 'lib\client.js'))) {
    Copy-Item $src $target -Recurse -Force
    Write-Host '    (mounted by copy; re-run this script after updating the plugin)'
}
Write-Host "    mounted at: $target"

Write-Host '==> Writing mobile-fit row into cordis.patch.yml'
if (-not (Test-Path $patchFile)) {
    Set-Content $patchFile "# Your patch layer for this dsh profile, applied after every bundle layer:`n[]" -Encoding UTF8
}

$content = Get-Content $patchFile -Raw
if ($content -notmatch 'id:\s*mobile-fit') {
    # The loader expects a top-level BLOCK sequence. A flow sequence `[ ... ]`
    # cannot contain block entries, so replace a lone `[]` with a block list.
    if ($content -match '(?s)^\s*\[\s*\]\s*$') {
        $content = $content -replace '(?s)^\s*\[\s*\]\s*$', ''
        $content = $content.TrimEnd() + @"

- insert:
    - id: mobile-fit
      name: 'mobile-fit'
"@ + "`n"
    } else {
        # Non-empty patch file: append before the closing `]` is impossible for
        # flow sequences; require the file to already use block style and
        # append a new top-level entry.
        $content = $content.TrimEnd() + @"

- insert:
    - id: mobile-fit
      name: 'mobile-fit'
"@ + "`n"
    }
    Set-Content $patchFile $content -Encoding UTF8
    Write-Host '    mobile-fit insert row added'
} else {
    Write-Host '    already present, skipped'
}

Write-Host ''
Write-Host '==> Done. Restart dsh web to take effect:' -ForegroundColor Green
Write-Host '    1. Close the current dsh web window (or: schtasks /end /tn dsh-web)'
Write-Host '    2. Start dsh web again, then reopen DSH Remote on the phone'
Write-Host '    3. A burger menu (top-left) inside the phone UI means it worked'
