[CmdletBinding(DefaultParameterSetName = 'Release')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Package')]
    [string]$PackagePath,
    [Parameter(Mandatory, ParameterSetName = 'Release')]
    [ValidatePattern('^[^/]+/[^/]+$')]
    [string]$Repository,
    [ValidatePattern('^[A-Fa-f0-9]{64}$')]
    [string]$ExpectedSha256,
    [string]$InstallDir,
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
$guardianHome = & (Join-Path $PSScriptRoot 'resolve-guardian-home.ps1')
if ([string]::IsNullOrWhiteSpace($InstallDir)) { $InstallDir = Join-Path $guardianHome 'app' }
$bundleExtractBaseDir = Join-Path $guardianHome 'bundle-cache'
$package = $PackagePath
$expectedHash = $ExpectedSha256

if ($PSCmdlet.ParameterSetName -eq 'Release') {
    $release = Invoke-RestMethod -Headers @{ 'User-Agent' = 'Codex-Guardian-Skill' } -Uri "https://api.github.com/repos/$Repository/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -match '^CodexGuardian-win-x64\.zip$' } | Select-Object -First 1
    $checksumAsset = $release.assets | Where-Object { $_.name -eq 'CodexGuardian-win-x64.zip.sha256' } | Select-Object -First 1
    if ($null -eq $asset) { throw 'The latest release does not contain CodexGuardian-win-x64.zip.' }
    if ($null -eq $checksumAsset) { throw 'The latest release does not contain the required SHA-256 checksum.' }
    $downloadDirectory = Join-Path $guardianHome 'downloads'
    New-Item -ItemType Directory -Force -Path $downloadDirectory | Out-Null
    $package = Join-Path $downloadDirectory 'CodexGuardian-win-x64.zip'
    $checksumPath = Join-Path $downloadDirectory 'CodexGuardian-win-x64.zip.sha256'
    Invoke-WebRequest -Headers @{ 'User-Agent' = 'Codex-Guardian-Skill' } -Uri $asset.browser_download_url -OutFile $package
    Invoke-WebRequest -Headers @{ 'User-Agent' = 'Codex-Guardian-Skill' } -Uri $checksumAsset.browser_download_url -OutFile $checksumPath
    $expectedHash = ((Get-Content -Raw -LiteralPath $checksumPath).Trim() -split '\s+')[0]
}

if (-not (Test-Path -LiteralPath $package)) { throw "Package not found: $package" }
if ([string]::IsNullOrWhiteSpace($expectedHash)) {
    $adjacentChecksum = "$package.sha256"
    if (Test-Path -LiteralPath $adjacentChecksum) {
        $expectedHash = ((Get-Content -Raw -LiteralPath $adjacentChecksum).Trim() -split '\s+')[0]
    }
}
if ([string]::IsNullOrWhiteSpace($expectedHash) -or $expectedHash -notmatch '^[A-Fa-f0-9]{64}$') {
    throw 'A valid SHA-256 checksum is required before installation.'
}
$actualHash = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash
if (-not [string]::Equals($actualHash, $expectedHash, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Package SHA-256 verification failed.'
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$installRoot = [IO.Path]::GetFullPath($InstallDir).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$archive = [IO.Compression.ZipFile]::OpenRead($package)
$fileCount = 0
$expandedBytes = 0L
try {
    foreach ($entry in $archive.Entries) {
        if ([string]::IsNullOrEmpty($entry.Name)) { continue }
        $fileCount++
        $expandedBytes += $entry.Length
        if ($fileCount -gt 2000) { throw 'Package contains too many files.' }
        if ($expandedBytes -gt 350MB) { throw 'Package exceeds the 350 MB expanded-size safety limit.' }
        $destination = [IO.Path]::GetFullPath((Join-Path $InstallDir $entry.FullName))
        if (-not $destination.StartsWith($installRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Package contains a path traversal entry.'
        }
        $unixFileType = ($entry.ExternalAttributes -shr 16) -band 0xF000
        if ($unixFileType -eq 0xA000) { throw 'Package contains an unsupported symbolic link.' }
    }
} finally {
    $archive.Dispose()
}
if ($fileCount -eq 0) { throw 'Package is empty.' }

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path $bundleExtractBaseDir | Out-Null
$installedWatcher = Join-Path $InstallDir 'CodexGuardian.Watcher.exe'
$watcherProcesses = @(Get-Process -Name 'CodexGuardian.Watcher' -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -and [string]::Equals([IO.Path]::GetFullPath($_.Path), [IO.Path]::GetFullPath($installedWatcher), [StringComparison]::OrdinalIgnoreCase)
})
if ($watcherProcesses.Count -gt 0) {
    try {
        $stopEvent = [Threading.EventWaitHandle]::OpenExisting('Local\CodexGuardian.Watcher.Stop')
        try { $stopEvent.Set() | Out-Null } finally { $stopEvent.Dispose() }
    } catch [Threading.WaitHandleCannotBeOpenedException] {
        throw 'The running follow-Codex watcher could not be stopped safely. Close it and retry the update.'
    }
    foreach ($watcherProcess in $watcherProcesses) {
        if (-not $watcherProcess.WaitForExit(5000)) {
            throw 'The follow-Codex watcher did not exit in time. No package files were overwritten.'
        }
    }
}
Expand-Archive -LiteralPath $package -DestinationPath $InstallDir -Force

$app = Join-Path $InstallDir 'CodexGuardian.App.exe'
if (-not (Test-Path -LiteralPath $app)) { throw 'Package is missing CodexGuardian.App.exe.' }
if (-not $NoLaunch) {
    $env:DOTNET_BUNDLE_EXTRACT_BASE_DIR = $bundleExtractBaseDir
    Start-Process -FilePath $app
    $followWatcher = Join-Path $InstallDir 'CodexGuardian.Watcher.exe'
    $runKey = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $runValue = if ($runKey.PSObject.Properties.Name -contains 'CodexGuardianFollowCodex') { $runKey.CodexGuardianFollowCodex } else { $null }
    $expectedRunValue = '"' + $followWatcher + '"'
    if ([string]::Equals($runValue, $expectedRunValue, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $followWatcher)) {
        Start-Process -FilePath $followWatcher
    }
}
[pscustomobject]@{
    status = 'installed'
    path = $app
    verified_sha256 = $actualHash
    files = $fileCount
    expanded_bytes = $expandedBytes
    bundle_cache = $bundleExtractBaseDir
    launched = -not $NoLaunch
} | ConvertTo-Json
