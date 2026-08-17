# Common helpers for dsh-remote scripts. Pure ASCII (PowerShell 5.1 safe).
# Dot-source from other scripts: . (Join-Path $PSScriptRoot 'lib-remote.ps1')

function Get-DshHome {
    if ($env:DSH_HOME) { return $env:DSH_HOME }
    return Join-Path $env:USERPROFILE '.dsh'
}

function Get-GatewayPort {
    if ($env:DSH_REMOTE_PORT) { return [int]$env:DSH_REMOTE_PORT }
    return 8082
}

function Get-GatewayUpstream {
    if ($env:DSH_REMOTE_UPSTREAM) { return $env:DSH_REMOTE_UPSTREAM }
    return 'http://127.0.0.1:3080'
}

function Get-LogDir {
    $dir = Join-Path (Get-DshHome) 'logs'
    New-Item -ItemType Directory -Force $dir | Out-Null
    return $dir
}

function Test-GatewayListening {
    $port = Get-GatewayPort
    $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    return [bool]$conn
}

function Get-Cloudflared {
    $cmd = Get-Command cloudflared.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    # Portable copy bundled with this project (tools\bin\cloudflared.exe)
    $local = Join-Path $PSScriptRoot '..\..\tools\bin\cloudflared.exe'
    if (Test-Path $local) { return (Resolve-Path $local).Path }
    $candidates = @(
        "${env:ProgramFiles(x86)}\cloudflared\cloudflared.exe",
        "$env:ProgramFiles\cloudflared\cloudflared.exe",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links\cloudflared.exe"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Get-Tailscale {
    $cmd = Get-Command tailscale.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $p = "$env:ProgramFiles\Tailscale\tailscale.exe"
    if (Test-Path $p) { return $p }
    return $null
}

function Read-RemotePassword {
    if ($env:DSH_REMOTE_TOKEN) { return $env:DSH_REMOTE_TOKEN }
    $file = Join-Path (Get-DshHome) 'dsh-remote.auth'
    if (-not (Test-Path $file)) {
        $file = Join-Path (Get-DshHome) 'mobile-remote.auth'
    }
    if (Test-Path $file) {
        $lines = Get-Content $file | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        foreach ($line in $lines) {
            if ($line -match '^password\s*=\s*(.+)$') { return $Matches[1] }
        }
        if ($lines.Count -eq 1) { return $lines[0] }
    }
    return ''
}

function Get-RemoteUser {
    if ($env:DSH_REMOTE_USER) { return $env:DSH_REMOTE_USER }
    $file = Join-Path (Get-DshHome) 'dsh-remote.auth'
    if (Test-Path $file) {
        foreach ($line in (Get-Content $file)) {
            if ($line -match '^user\s*=\s*(.+)$') { return $Matches[1].Trim() }
        }
    }
    return 'dsh'
}

function Wait-GatewayListening([int]$timeoutSeconds = 30) {
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-GatewayListening) { return $true }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

function Start-GatewayHidden {
    # Starts node gateway.mjs hidden with a 10s-restart watchdog, returns the
    # watchdog process. Log: ~/.dsh/logs/dsh-remote-gateway.log
    $node = (Get-Command node.exe -ErrorAction Stop).Source
    $script = Join-Path $PSScriptRoot 'run-gateway-watchdog.ps1'
    $log = Join-Path (Get-LogDir) 'dsh-remote-gateway.log'
    $arg = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $script
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $arg -WindowStyle Hidden -PassThru
    return $p
}

function Start-CloudflaredHidden {
    # Starts the cloudflared quick tunnel hidden with watchdog; returns the
    # watchdog process. Log: ~/.dsh/logs/dsh-remote-cloudflared.log
    $script = Join-Path $PSScriptRoot 'run-cloudflared-watchdog.ps1'
    $log = Join-Path (Get-LogDir) 'dsh-remote-cloudflared.log'
    $arg = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $script
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $arg -WindowStyle Hidden -PassThru
    return $p
}

function Wait-CloudflaredUrl([int]$timeoutSeconds = 60) {
    # cloudflared prints the trycloudflare URL on STDERR. Wait for BOTH the
    # URL and a "Registered tunnel connection" line: the URL alone can be
    # cloudflared's own api.trycloudflare.com host in a failure line, and the
    # edge returns 404/530 until a connection actually registers.
    $log = Join-Path (Get-LogDir) 'dsh-remote-cloudflared.err.log'
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)
    $url = $null
    while ((Get-Date) -lt $deadline) {
        if (Test-Path $log) {
            $text = Get-Content $log -Raw -ErrorAction SilentlyContinue
            if ($text -match 'https://(?!api\.)[a-z0-9-]+\.trycloudflare\.com') {
                $url = $Matches[0]
            }
            if ($url -and ($text -match 'Registered tunnel connection')) {
                return $url
            }
        }
        Start-Sleep -Milliseconds 700
    }
    return $url
}

function Get-Ssh {
    $cmd = Get-Command ssh.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $p = "$env:SystemRoot\System32\OpenSSH\ssh.exe"
    if (Test-Path $p) { return $p }
    return $null
}

function Start-LocalhostRunHidden {
    # Starts the localhost.run SSH reverse tunnel hidden with watchdog.
    # The public https://xxxx.lhr.life URL is parsed from
    # ~/.dsh/logs/dsh-remote-localhostrun.log
    $script = Join-Path $PSScriptRoot 'run-localhostrun-watchdog.ps1'
    $arg = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $script
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $arg -WindowStyle Hidden -PassThru
    return $p
}

function Wait-LocalhostRunUrl([int]$timeoutSeconds = 45) {
    $log = Join-Path (Get-LogDir) 'dsh-remote-localhostrun.log'
    $urlFile = Join-Path (Get-DshHome) 'dsh-remote-url.txt'
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path $log) {
            $text = Get-Content $log -Raw -ErrorAction SilentlyContinue
            $ms = [regex]::Matches($text, 'https://[a-z0-9-]+\.lhr\.life')
            if ($ms.Count -gt 0) {
                # The log keeps history; only the LAST line belongs to the
                # currently forwarded tunnel.
                $latest = $ms[$ms.Count - 1].Value
                Set-Content $urlFile $latest -Encoding ASCII
                return $latest
            }
        }
        if (Test-Path $urlFile) {
            $saved = (Get-Content $urlFile -Raw -ErrorAction SilentlyContinue).Trim()
            if ($saved -match '^https://[a-z0-9-]+\.lhr\.life$') { return $saved }
        }
        Start-Sleep -Milliseconds 700
    }
    return $null
}

function Test-LocalhostRunRunning {
    Get-CimInstance Win32_Process -Filter "Name='ssh.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'nokey@localhost\.run' } |
        Select-Object -First 1 | ForEach-Object { $true }
}

function Stop-LocalhostRunTunnel {
    Get-CimInstance Win32_Process -Filter "Name='ssh.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'nokey@localhost\.run' } |
        ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'run-localhostrun-watchdog\.ps1' } |
        ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }
}

function Get-ServeoKey {
    $p = Join-Path $env:USERPROFILE '.ssh\dsh_serveo'
    if (Test-Path $p) { return $p }
    return $null
}

function Start-ServeoHidden([string]$Subdomain = 'dshremote') {
    $script = Join-Path $PSScriptRoot 'run-serveo-watchdog.ps1'
    $arg = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Subdomain {1}' -f $script, $Subdomain
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $arg -WindowStyle Hidden -PassThru
    return $p
}

function Test-ServeoRunning {
    Get-CimInstance Win32_Process -Filter "Name='ssh.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'serveo\.net' } |
        Select-Object -First 1 | ForEach-Object { $true }
}

function Stop-ServeoTunnel {
    Get-CimInstance Win32_Process -Filter "Name='ssh.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'serveo\.net' } |
        ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'run-serveo-watchdog\.ps1' } |
        ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }
}

function Stop-GatewayProcesses {
    $port = Get-GatewayPort
    $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    foreach ($c in $conns) {
        try { Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue } catch {}
    }
    # watchdog powershell instances
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'run-gateway-watchdog\.ps1' } |
        ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }
}

function Stop-CloudflaredTunnel {
    Get-CimInstance Win32_Process -Filter "Name='cloudflared.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'tunnel\s+--url\s+http://127\.0\.0\.1:(8082|\d+)' } |
        ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'run-cloudflared-watchdog\.ps1' } |
        ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }
}
