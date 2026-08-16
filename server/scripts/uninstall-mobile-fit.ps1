# Remove the mobile-fit plugin from the local dsh web profile.
# Pure ASCII (PowerShell 5.1 safe).
param(
    [string]$DshHome = $env:DSH_HOME
)

$ErrorActionPreference = 'Stop'
if (-not $DshHome) { $DshHome = Join-Path $env:USERPROFILE '.dsh' }

$profileDir = Join-Path $DshHome 'profiles\web'
$patchFile = Join-Path $profileDir 'cordis.patch.yml'
$mount = Join-Path $profileDir 'node_modules\mobile-fit'

if (Test-Path $patchFile) {
    $content = Get-Content $patchFile -Raw
    if ($content -match 'id:\s*mobile-fit') {
        # Remove the whole "- insert:" block whose item id is mobile-fit.
        $content = $content -replace '(?ms)\s*- insert:\s*\r?\n(?:\s+- id:\s*mobile-fit\s*\r?\n\s*name:\s*''mobile-fit''\s*\r?\n)\s*', "`r`n"
        $content = $content.TrimEnd() + "`r`n"
        # If only comments remain, restore the canonical empty patch file.
        if ($content -notmatch '-\s+insert:') {
            $content = "# Your patch layer for this dsh profile, applied after every bundle layer:`r`n[]"
        }
        Set-Content $patchFile $content -Encoding UTF8
        Write-Host 'mobile-fit patch row removed.'
    } else {
        Write-Host 'mobile-fit row not present in patch file.'
    }
}

if (Test-Path $mount) {
    Remove-Item $mount -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "mount removed: $mount"
}

Write-Host ''
Write-Host 'Restart dsh web to apply the removal.'
