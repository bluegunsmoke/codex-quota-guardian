[CmdletBinding()]
param()

$root = & (Join-Path $PSScriptRoot 'resolve-guardian-home.ps1')
[pscustomobject]@{
    status = 'confirmation_required'
    app_directory = Join-Path $root 'app'
    settings_file = Join-Path $root 'data\settings.json'
    history_file = Join-Path $root 'data\quota-history.jsonl'
    startup_entry = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\CodexGuardian'
    follow_codex_startup_entry = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\CodexGuardianFollowCodex'
    watcher_process = Join-Path $root 'app\CodexGuardian.Watcher.exe'
    message = 'This guide performs no deletion. Ask the user separately whether to remove only the app or also settings/history, then carry out exactly the confirmed scope.'
} | ConvertTo-Json
