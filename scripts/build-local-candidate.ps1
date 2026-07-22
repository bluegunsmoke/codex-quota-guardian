[CmdletBinding()]
param(
    [string]$Configuration = 'Release',
    [string]$Runtime = 'win-x64'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$version = '1.0.0-rc.14'
$localDotnet = Join-Path $root 'work\.dotnet\dotnet.exe'
$dotnet = if (Test-Path -LiteralPath $localDotnet) { $localDotnet } else { 'dotnet' }
$candidateRoot = Join-Path $root "artifacts\local-candidate\$version"
$publishDir = Join-Path $candidateRoot $Runtime
$package = Join-Path $candidateRoot "CodexGuardian-local-test-$version-$Runtime.zip"
$buildStamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# Never publish over an existing candidate. Besides preserving user files, this
# prevents stale assemblies from an older dependency graph entering a release.
if ((Test-Path -LiteralPath $publishDir) -and (Get-ChildItem -LiteralPath $publishDir -Force | Select-Object -First 1)) {
    $publishDir = Join-Path $candidateRoot "$Runtime-$buildStamp"
    $package = Join-Path $candidateRoot "CodexGuardian-local-test-$version-$Runtime-$buildStamp.zip"
}

New-Item -ItemType Directory -Force -Path $publishDir | Out-Null
& $dotnet publish (Join-Path $root 'src\CodexGuardian.App\CodexGuardian.App.csproj') `
    --configuration $Configuration `
    --runtime $Runtime `
    --self-contained true `
    -p:PublishSingleFile=false `
    -p:DebugType=None `
    -p:DebugSymbols=false `
    --output $publishDir | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'dotnet publish failed.' }

$watcherPublishDir = $publishDir
& $dotnet publish (Join-Path $root 'src\CodexGuardian.Watcher\CodexGuardian.Watcher.csproj') `
    --configuration $Configuration `
    --runtime $Runtime `
    --self-contained true `
    -p:PublishAot=false `
    -p:PublishSingleFile=true `
    -p:PublishTrimmed=true `
    -p:TrimMode=full `
    -p:IncludeNativeLibrariesForSelfExtract=false `
    -p:EnableCompressionInSingleFile=false `
    -p:DebugType=None `
    -p:DebugSymbols=false `
    --output $watcherPublishDir | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Trimmed self-contained watcher publish failed.' }
$watcher = Join-Path $watcherPublishDir 'CodexGuardian.Watcher.exe'
if (-not (Test-Path -LiteralPath $watcher)) { throw 'Trimmed self-contained watcher executable was not produced.' }

Copy-Item -LiteralPath (Join-Path $root 'README.md') -Destination $publishDir -Force
Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination $publishDir -Force
Copy-Item -LiteralPath (Join-Path $root 'docs\privacy.md') -Destination $publishDir -Force
Copy-Item -LiteralPath (Join-Path $root 'docs\local-test-checklist.md') -Destination $publishDir -Force
Copy-Item -LiteralPath (Join-Path $root 'THIRD-PARTY-NOTICES.md') -Destination $publishDir -Force

if (Test-Path -LiteralPath $package) {
    $package = Join-Path $candidateRoot "CodexGuardian-local-test-$version-$Runtime-$buildStamp.zip"
}
Compress-Archive -Path (Join-Path $publishDir '*') -DestinationPath $package
$packageHash = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash
$checksumPath = "$package.sha256"
Set-Content -LiteralPath $checksumPath -Value "$packageHash  $(Split-Path -Leaf $package)" -Encoding ASCII
[pscustomobject]@{
    status = 'built'
    version = $version
    folder = $publishDir
    package = $package
    checksum = $checksumPath
    sha256 = $packageHash
} | ConvertTo-Json
