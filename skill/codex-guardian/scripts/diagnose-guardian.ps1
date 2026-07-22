[CmdletBinding()]
param([string]$InstallDir)

$ErrorActionPreference = 'Stop'
$guardianHome = & (Join-Path $PSScriptRoot 'resolve-guardian-home.ps1')
if ([string]::IsNullOrWhiteSpace($InstallDir)) { $InstallDir = Join-Path $guardianHome 'app' }
$sessionsRoot = Join-Path $env:USERPROFILE '.codex\sessions'
$appPath = Join-Path $InstallDir 'CodexGuardian.App.exe'

$result = [ordered]@{
    status = 'unknown'
    windows_version = [Environment]::OSVersion.VersionString
    app_installed = Test-Path -LiteralPath $appPath
    session_directory = Test-Path -LiteralPath $sessionsRoot
    metadata_found = $false
    freshness = $null
    five_hour_remaining_percent = $null
    weekly_remaining_percent = $null
    message = $null
}

if (-not $result.session_directory) {
    $result.status = 'no_session_directory'
    $result.message = 'Run a Codex task in this Windows profile, then diagnose again.'
    $result | ConvertTo-Json
    exit 2
}

$files = Get-ChildItem -LiteralPath $sessionsRoot -Recurse -Filter 'rollout-*.jsonl' -File |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 12

$snapshot = $null
foreach ($file in $files) {
    foreach ($line in Get-Content -LiteralPath $file.FullName -Encoding UTF8) {
        if ($line -notlike '*"rate_limits"*') { continue }
        try {
            $event = $line | ConvertFrom-Json
            $limits = $event.payload.rate_limits
            if ($null -eq $limits.primary -or $null -eq $limits.secondary) { continue }
            $primary = [double]$limits.primary.used_percent
            $secondary = [double]$limits.secondary.used_percent
            if ($primary -lt 0 -or $primary -gt 100 -or $secondary -lt 0 -or $secondary -gt 100) { continue }
            $snapshot = [ordered]@{
                captured = [DateTimeOffset]::Parse($event.timestamp)
                primary = [int][Math]::Round($primary)
                secondary = [int][Math]::Round($secondary)
            }
        } catch {
            continue
        }
    }
    if ($null -ne $snapshot) { break }
}

if ($null -eq $snapshot) {
    $result.status = 'metadata_not_found'
    $result.message = 'No validated rate-limit metadata was found. Run a Codex task or update Guardian.'
    $result | ConvertTo-Json
    exit 3
}

$age = [DateTimeOffset]::UtcNow - $snapshot.captured
$result.metadata_found = $true
$result.five_hour_remaining_percent = 100 - $snapshot.primary
$result.weekly_remaining_percent = 100 - $snapshot.secondary
$result.freshness = if ($age.TotalMinutes -le 5) { 'fresh' } elseif ($age.TotalHours -le 1) { 'stale' } else { 'expired' }
$result.status = if ($result.app_installed) { 'healthy' } else { 'app_not_installed' }
$result.message = if ($result.app_installed) { 'Local quota metadata is readable.' } else { 'Metadata is readable; install the Guardian app.' }
$result | ConvertTo-Json
exit 0
