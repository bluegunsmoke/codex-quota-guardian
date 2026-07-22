[CmdletBinding()]
param()

$configured = [Environment]::GetEnvironmentVariable('CODEX_GUARDIAN_HOME', 'User')
if ([string]::IsNullOrWhiteSpace($configured)) { $configured = $env:CODEX_GUARDIAN_HOME }
if ([string]::IsNullOrWhiteSpace($configured)) {
    $configured = Join-Path $env:USERPROFILE '.codex-guardian'
}
if (-not [IO.Path]::IsPathRooted($configured) -or $configured -match '^[A-Za-z]:[^\\]') {
    throw 'CODEX_GUARDIAN_HOME must be an absolute path.'
}
[IO.Path]::GetFullPath($configured)
