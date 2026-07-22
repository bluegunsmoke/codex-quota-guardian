[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$auditRoot = Join-Path $root 'artifacts\audit\installer-safety'
$maliciousPackage = Join-Path $auditRoot 'path-traversal.zip'
$installTarget = Join-Path $auditRoot 'install-target'
New-Item -ItemType Directory -Force -Path $auditRoot | Out-Null

Add-Type -AssemblyName System.IO.Compression
$stream = [IO.File]::Open($maliciousPackage, [IO.FileMode]::Create, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
try {
    $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $false)
    try {
        $entry = $archive.CreateEntry('../escape.txt')
        $writer = [IO.StreamWriter]::new($entry.Open())
        try { $writer.Write('must not escape') } finally { $writer.Dispose() }
    } finally {
        $archive.Dispose()
    }
} finally {
    $stream.Dispose()
}

$hash = (Get-FileHash -LiteralPath $maliciousPackage -Algorithm SHA256).Hash
$checksumRejected = $false
try {
    & (Join-Path $root 'skill\codex-guardian\scripts\install-guardian.ps1') `
        -PackagePath $maliciousPackage `
        -ExpectedSha256 ('0' * 64) `
        -InstallDir $installTarget `
        -NoLaunch | Out-Null
} catch {
    if ($_.Exception.Message -notmatch 'SHA-256 verification failed') { throw }
    $checksumRejected = $true
}
if (-not $checksumRejected) { throw 'Installer accepted an invalid package checksum.' }

$rejected = $false
try {
    & (Join-Path $root 'skill\codex-guardian\scripts\install-guardian.ps1') `
        -PackagePath $maliciousPackage `
        -ExpectedSha256 $hash `
        -InstallDir $installTarget `
        -NoLaunch | Out-Null
} catch {
    if ($_.Exception.Message -notmatch 'path traversal') { throw }
    $rejected = $true
}

if (-not $rejected) { throw 'Installer accepted a path traversal package.' }
if (Test-Path -LiteralPath (Join-Path $auditRoot 'escape.txt')) {
    throw 'Path traversal test wrote outside the install directory.'
}

[pscustomobject]@{
    status = 'passed'
    checksum_mismatch_rejected = $true
    path_traversal_rejected = $true
} | ConvertTo-Json
