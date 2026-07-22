[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$sessionsRoot = Join-Path $env:USERPROFILE '.codex\sessions'
$guardianHome = & (Join-Path $PSScriptRoot 'resolve-guardian-home.ps1')
$os = [Environment]::OSVersion.Version

[pscustomobject]@{
    status = if ($env:OS -eq 'Windows_NT' -and $os.Major -ge 10) { 'supported' } else { 'unsupported' }
    operating_system = [Environment]::OSVersion.VersionString
    architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    is_64_bit = [Environment]::Is64BitOperatingSystem
    codex_sessions_present = Test-Path -LiteralPath $sessionsRoot
    guardian_home = $guardianHome
    guardian_app_directory = Join-Path $guardianHome 'app'
    guardian_data_directory = Join-Path $guardianHome 'data'
    requires_admin = $false
    message = 'Guardian is a per-user, self-contained Windows application and does not require administrator rights.'
} | ConvertTo-Json
