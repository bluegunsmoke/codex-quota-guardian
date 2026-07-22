[CmdletBinding()]
param(
    [int]$Minutes = 10,
    [int]$SampleSeconds = 30,
    [int]$WarmupSeconds = 30,
    [string]$Executable
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $Executable) {
    $Executable = Join-Path $root 'artifacts\local-candidate\1.0.0-rc.14\win-x64\CodexGuardian.App.exe'
}
if (-not (Test-Path -LiteralPath $Executable)) { throw "Candidate executable not found: $Executable" }
if ($Minutes -lt 1) { throw 'Minutes must be at least 1.' }
if ($SampleSeconds -lt 5) { throw 'SampleSeconds must be at least 5.' }

$guardianHome = [Environment]::GetEnvironmentVariable('CODEX_GUARDIAN_HOME', 'User')
if ([string]::IsNullOrWhiteSpace($guardianHome)) { $guardianHome = $env:CODEX_GUARDIAN_HOME }
if ([string]::IsNullOrWhiteSpace($guardianHome)) { $guardianHome = Join-Path $env:USERPROFILE '.codex-guardian' }
if (-not [string]::IsNullOrWhiteSpace($guardianHome)) {
    $env:DOTNET_BUNDLE_EXTRACT_BASE_DIR = Join-Path $guardianHome 'bundle-cache'
    New-Item -ItemType Directory -Force -Path $env:DOTNET_BUNDLE_EXTRACT_BASE_DIR | Out-Null
}

function Get-DirectoryBytes([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return 0L }
    $sum = (Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sum) { return 0L }
    return [long]$sum
}

$dataPath = Join-Path $guardianHome 'data'
$bundlePath = Join-Path $guardianHome 'bundle-cache'
$dataBytesBefore = Get-DirectoryBytes $dataPath
$bundleBytesBefore = Get-DirectoryBytes $bundlePath

$process = Start-Process -FilePath $Executable -PassThru
$samples = [System.Collections.Generic.List[object]]::new()
try {
    Start-Sleep -Seconds $WarmupSeconds
    $sampleCount = [Math]::Ceiling(($Minutes * 60) / $SampleSeconds) + 1
    for ($index = 0; $index -lt $sampleCount; $index++) {
        if ($index -gt 0) { Start-Sleep -Seconds $SampleSeconds }
        $current = Get-Process -Id $process.Id -ErrorAction Stop
        $samples.Add([pscustomobject]@{
            elapsed_seconds = $index * $SampleSeconds
            responding = $current.Responding
            working_set_mb = [Math]::Round($current.WorkingSet64 / 1MB, 1)
            private_memory_mb = [Math]::Round($current.PrivateMemorySize64 / 1MB, 1)
            handles = $current.HandleCount
            threads = $current.Threads.Count
            total_cpu_seconds = [Math]::Round($current.TotalProcessorTime.TotalSeconds, 3)
        })
        if (-not $current.Responding) { throw "Guardian stopped responding at sample $index." }
    }
} finally {
    if (-not $process.HasExited) { Stop-Process -Id $process.Id }
}

$privateGrowth = $samples[-1].private_memory_mb - $samples[0].private_memory_mb
$workingSetGrowth = $samples[-1].working_set_mb - $samples[0].working_set_mb
$handleGrowth = $samples[-1].handles - $samples[0].handles
$threadGrowth = $samples[-1].threads - $samples[0].threads
$elapsedSeconds = [Math]::Max(1, $samples[-1].elapsed_seconds - $samples[0].elapsed_seconds)
$cpuSeconds = $samples[-1].total_cpu_seconds - $samples[0].total_cpu_seconds
$averageCpuPercent = 100 * $cpuSeconds / ($elapsedSeconds * [Environment]::ProcessorCount)
$dataGrowth = (Get-DirectoryBytes $dataPath) - $dataBytesBefore
$bundleGrowth = (Get-DirectoryBytes $bundlePath) - $bundleBytesBefore
$passed = $privateGrowth -lt 40 -and $workingSetGrowth -lt 40 -and $handleGrowth -lt 30 -and `
    $threadGrowth -lt 5 -and $averageCpuPercent -lt 1.5 -and $dataGrowth -lt 2MB -and $bundleGrowth -eq 0
$result = [pscustomobject]@{
    status = if ($passed) { 'passed' } else { 'failed' }
    duration_minutes = $Minutes
    warmup_seconds = $WarmupSeconds
    samples = $samples.Count
    private_memory_growth_mb = [Math]::Round($privateGrowth, 1)
    working_set_growth_mb = [Math]::Round($workingSetGrowth, 1)
    handle_growth = $handleGrowth
    thread_growth = $threadGrowth
    average_cpu_percent = [Math]::Round($averageCpuPercent, 3)
    data_growth_bytes = $dataGrowth
    bundle_cache_growth_bytes = $bundleGrowth
    first = $samples[0]
    last = $samples[-1]
    series = $samples
}
$reportPath = Join-Path $root 'artifacts\local-candidate\residency-soak.json'
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportPath -Encoding UTF8
$result | ConvertTo-Json -Depth 5
if (-not $passed) { exit 1 }
