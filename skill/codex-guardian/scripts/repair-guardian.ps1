[CmdletBinding(DefaultParameterSetName = 'Inspect')]
param(
    [Parameter(ParameterSetName = 'Release')]
    [string]$Repository,
    [Parameter(ParameterSetName = 'Package')]
    [string]$PackagePath,
    [string]$InstallDir,
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
$guardianHome = & (Join-Path $PSScriptRoot 'resolve-guardian-home.ps1')
if ([string]::IsNullOrWhiteSpace($InstallDir)) { $InstallDir = Join-Path $guardianHome 'app' }
$diagnostic = & (Join-Path $PSScriptRoot 'diagnose-guardian.ps1') -InstallDir $InstallDir | ConvertFrom-Json

if ($diagnostic.status -eq 'healthy') {
    [pscustomobject]@{ status = 'healthy'; action = 'none'; message = $diagnostic.message } | ConvertTo-Json
    exit 0
}

if ($diagnostic.status -eq 'app_not_installed' -and ($Repository -or $PackagePath)) {
    if ($PackagePath) {
        & (Join-Path $PSScriptRoot 'install-guardian.ps1') -PackagePath $PackagePath -InstallDir $InstallDir -NoLaunch:$NoLaunch
    } else {
        & (Join-Path $PSScriptRoot 'install-guardian.ps1') -Repository $Repository -InstallDir $InstallDir -NoLaunch:$NoLaunch
    }
    exit $LASTEXITCODE
}

$action = switch ($diagnostic.status) {
    'no_session_directory' { 'run_codex_task' }
    'metadata_not_found' { 'run_codex_task_or_update' }
    'app_not_installed' { 'install' }
    default { 'inspect' }
}
[pscustomobject]@{ status = $diagnostic.status; action = $action; message = $diagnostic.message } | ConvertTo-Json
