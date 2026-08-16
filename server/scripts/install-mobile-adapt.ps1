# Mount the dsh-mobile-adapt plugin (juanlian583, MIT) into the local dsh web
# profile and switch the patch layer from the older mobile-fit row to it.
# Idempotent. Pure ASCII (PowerShell 5.1 safe).
param(
    [string]$DshHome = $env:DSH_HOME
)

$ErrorActionPreference = 'Stop'
if (-not $DshHome) { $DshHome = Join-Path $env:USERPROFILE '.dsh' }

$profileDir = Join-Path $DshHome 'profiles\web'
$patchFile = Join-Path $profileDir 'cordis.patch.yml'
$src = Join-Path $PSScriptRoot '..\mobile-adapt'
if (Test-Path (Join-Path $src 'package.json')) { $src = (Resolve-Path $src).Path }

if (-not (Test-Path $profileDir)) { throw "dsh web profile not found: $profileDir" }

Write-Host '==> Mounting @dsh/mobile-adapt plugin'
$scope = Join-Path $profileDir 'node_modules\@dsh'
New-Item -ItemType Directory -Force $scope | Out-Null
$target = Join-Path $scope 'mobile-adapt'
if ((Test-Path $target) -and -not (Test-Path (Join-Path $target 'lib\client.js'))) {
    Remove-Item $target -Recurse -Force
}
if (-not (Test-Path (Join-Path $target 'lib\client.js'))) {
    try { cmd /c mklink /J "$target" "$src" | Out-Null } catch {}
}
if (-not (Test-Path (Join-Path $target 'lib\client.js'))) {
    Copy-Item $src $target -Recurse -Force
}
Write-Host "    mounted at: $target"

Write-Host '==> Updating cordis.patch.yml'
if (-not (Test-Path $patchFile)) {
    Set-Content $patchFile "# Your patch layer for this dsh profile, applied after every bundle layer:`n[]" -Encoding UTF8
}
$content = Get-Content $patchFile -Raw

# Remove the old mobile-fit insert block (if present).
if ($content -match 'id:\s*mobile-fit') {
    $content = $content -replace '(?ms)\s*- insert:\s*\r?\n(?:\s+- id:\s*mobile-fit\s*\r?\n\s*name:\s*''mobile-fit''\s*\r?\n)\s*', "`r`n"
}

if ($content -notmatch 'id:\s*mobile-adapt') {
    $entry = @"

- insert:
    - id: mobile-adapt
      name: '@dsh/mobile-adapt'
"@
    $content = $content.TrimEnd() + "`r`n" + $entry + "`r`n"
    Set-Content $patchFile $content -Encoding UTF8
    Write-Host '    mobile-adapt insert row added'
} else {
    Write-Host '    mobile-adapt row already present'
}

# Remove the old mobile-fit mount.
$oldMount = Join-Path $profileDir 'node_modules\mobile-fit'
if (Test-Path $oldMount) {
    Remove-Item $oldMount -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host '    removed old mobile-fit mount'
}

Write-Host ''
Write-Host '==> Done. Restart dsh web to apply (close the window and start again).'
