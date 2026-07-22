[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$localDotnet = Join-Path $root 'work\.dotnet\dotnet.exe'
$dotnet = if (Test-Path -LiteralPath $localDotnet) { $localDotnet } else { 'dotnet' }

& $dotnet restore (Join-Path $root 'CodexGuardian.sln')
if ($LASTEXITCODE -ne 0) { throw 'Restore failed.' }
& $dotnet build (Join-Path $root 'CodexGuardian.sln') --configuration Release --no-restore
if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }
& $dotnet test (Join-Path $root 'tests\CodexGuardian.Tests\CodexGuardian.Tests.csproj') --configuration Release --no-build
if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }

$vulnerabilityJson = & $dotnet list (Join-Path $root 'CodexGuardian.sln') package --vulnerable --include-transitive --format json
if ($LASTEXITCODE -ne 0) { throw 'Dependency vulnerability scan failed.' }
$vulnerabilityReport = $vulnerabilityJson | ConvertFrom-Json
$vulnerableProjects = @($vulnerabilityReport.projects | Where-Object {
    $_.PSObject.Properties.Name -contains 'frameworks' -and $null -ne $_.frameworks
})
if ($vulnerableProjects.Count -ne 0) { throw 'Known vulnerable NuGet dependencies were found.' }

& (Join-Path $root 'scripts\validate-skill.ps1') | Out-Null
& (Join-Path $root 'scripts\validate-localization.ps1') | Out-Null
& (Join-Path $root 'scripts\test-installer-safety.ps1') | Out-Null
$diagnosticJson = & $dotnet run --project (Join-Path $root 'src\CodexGuardian.Cli\CodexGuardian.Cli.csproj') --configuration Release --no-build
$diagnostic = $diagnosticJson | ConvertFrom-Json
if ($null -eq $diagnostic.five_hour -or $null -eq $diagnostic.weekly) { throw 'Diagnostic CLI did not return both quota windows.' }
if ($diagnosticJson -match '(?i)prompt|response|cookie|auth[_-]?token|access[_-]?token') { throw 'Diagnostic output contains a forbidden sensitive field.' }

$sourceFiles = Get-ChildItem (Join-Path $root 'src') -Recurse -File -Include '*.cs','*.xaml'
$networkMatches = $sourceFiles | Select-String -Pattern 'HttpClient|HttpWebRequest|WebClient|System\.Net\.Sockets' -CaseSensitive
if ($networkMatches) { throw 'Unexpected network API reference found in application source.' }
$providerSource = Get-Content -Raw -LiteralPath (Join-Path $root 'src\CodexGuardian.Providers\CodexAppServerQuotaProbe.cs')
$accountMethodMatches = [regex]::Matches($providerSource, 'method\s*=\s*"(account/[^"]+)"')
if ($accountMethodMatches.Count -ne 1 -or $accountMethodMatches[0].Groups[1].Value -ne 'account/rateLimits/read') {
    throw 'Active quota provider must expose exactly the fixed account/rateLimits/read method.'
}
if ($providerSource -match '(?i)auth\.json|access[_-]?token|refresh[_-]?token') {
    throw 'Active quota provider source references a forbidden credential field.'
}
$deletionMatches = Get-ChildItem (Join-Path $root 'skill\codex-guardian\scripts') -File -Filter '*.ps1' |
    Select-String -Pattern '\b(Remove-Item|rd|rmdir|del)\b' -CaseSensitive
if ($deletionMatches) { throw 'A Skill script contains a deletion command.' }

$packageResult = & (Join-Path $root 'scripts\build-local-candidate.ps1') | ConvertFrom-Json
$publishFiles = @(Get-ChildItem -LiteralPath $packageResult.folder -Recurse -File)
$publishBytes = ($publishFiles | Measure-Object -Property Length -Sum).Sum
$packageBytes = (Get-Item -LiteralPath $packageResult.package).Length
$launcher = Get-Item -LiteralPath (Join-Path $packageResult.folder 'CodexGuardian.App.exe')
$watcher = Get-Item -LiteralPath (Join-Path $packageResult.folder 'CodexGuardian.Watcher.exe')
$forbiddenPackageFiles = @($publishFiles | Where-Object {
    $_.Name -in @('settings.json', 'window-state.json', 'auth.json') -or
    $_.Extension -eq '.jsonl' -or
    $_.Extension -eq '.pdb'
})
if ($forbiddenPackageFiles.Count -ne 0) { throw 'Candidate contains user data, logs, secrets, or debug symbols.' }
if ($launcher.Length -ge 10MB) { throw 'Candidate launcher is unexpectedly large; single-file bundling may be enabled.' }
if ($watcher.Length -ge 15MB) { throw 'Follow-Codex watcher exceeds the 15 MB release budget.' }
if ($publishBytes -ge 230MB) { throw 'Uncompressed candidate exceeds the 230 MB release budget.' }
if ($packageBytes -ge 120MB) { throw 'ZIP candidate exceeds the 120 MB release budget.' }
if (-not (Test-Path -LiteralPath (Join-Path $packageResult.folder 'THIRD-PARTY-NOTICES.md'))) {
    throw 'Candidate is missing THIRD-PARTY-NOTICES.md.'
}
$hash = Get-FileHash -LiteralPath $packageResult.package -Algorithm SHA256
if (-not (Test-Path -LiteralPath $packageResult.checksum)) { throw 'Candidate checksum file is missing.' }
$declaredHash = ((Get-Content -Raw -LiteralPath $packageResult.checksum).Trim() -split '\s+')[0]
if (-not [string]::Equals($hash.Hash, $declaredHash, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Candidate checksum file does not match the ZIP.'
}
$installResult = & (Join-Path $root 'skill\codex-guardian\scripts\install-guardian.ps1') `
    -PackagePath $packageResult.package `
    -InstallDir $packageResult.folder `
    -NoLaunch | ConvertFrom-Json
if (-not [string]::Equals($installResult.verified_sha256, $hash.Hash, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Installer did not report the audited package hash.'
}
[pscustomobject]@{
    status = 'passed'
    build = 'zero warnings required by Directory.Build.props'
    tests = 'passed'
    skill = 'valid'
    installer_safety = 'checksum and path traversal gates passed'
    installer_archive_files = $installResult.files
    installer_expanded_mb = [Math]::Round($installResult.expanded_bytes / 1MB, 2)
    localization = 'en-US and zh-CN catalogs valid'
    vulnerable_dependencies = 0
    provider = $diagnostic.source
    freshness = $diagnostic.freshness
    network_api_references = 0
    active_quota_probe = 'bounded signed-in Codex app-server account/rateLimits/read'
    deletion_commands = 0
    candidate_files = $publishFiles.Count
    candidate_folder_mb = [Math]::Round($publishBytes / 1MB, 2)
    candidate_zip_mb = [Math]::Round($packageBytes / 1MB, 2)
    launcher_mb = [Math]::Round($launcher.Length / 1MB, 2)
    watcher_mb = [Math]::Round($watcher.Length / 1MB, 2)
    package = $packageResult.package
    sha256 = $hash.Hash
} | ConvertTo-Json
