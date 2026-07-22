[CmdletBinding()]
param(
    [string]$Executable,
    [int]$DurationMinutes = 30,
    [int]$SampleSeconds = 15,
    [string]$BundleCacheDirectory = $env:DOTNET_BUNDLE_EXTRACT_BASE_DIR
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Executable)) {
    $Executable = Join-Path $root 'artifacts\local-candidate\1.0.0-rc.14\win-x64\CodexGuardian.Watcher.exe'
}
if (-not (Test-Path -LiteralPath $Executable)) { throw "Watcher not found: $Executable" }
if ($DurationMinutes -lt 1 -or $SampleSeconds -lt 5) { throw 'Duration must be at least 1 minute and sample interval at least 5 seconds.' }

function Get-DirectoryBytes([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) { return 0L }
    return [long]((Get-ChildItem -LiteralPath $Path -Recurse -File | Measure-Object -Property Length -Sum).Sum)
}

$cacheBefore = Get-DirectoryBytes $BundleCacheDirectory
$process = Start-Process -FilePath $Executable -PassThru
$samples = @()
$started = Get-Date
try {
    do {
        $current = Get-Process -Id $process.Id -ErrorAction Stop
        $samples += [pscustomobject]@{
            at = (Get-Date).ToString('o')
            cpu = $current.CPU
            private = $current.PrivateMemorySize64
            working_set = $current.WorkingSet64
            handles = $current.HandleCount
            threads = $current.Threads.Count
        }
        if (((Get-Date) - $started).TotalMinutes -ge $DurationMinutes) { break }
        Start-Sleep -Seconds $SampleSeconds
    } while ($true)
} finally {
    try {
        $stopEvent = [Threading.EventWaitHandle]::OpenExisting('Local\CodexGuardian.Watcher.Stop')
        try { $stopEvent.Set() | Out-Null } finally { $stopEvent.Dispose() }
    } catch [Threading.WaitHandleCannotBeOpenedException] {
        # The watcher already exited; the result below will fail the responsiveness gate.
    }
    $running = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
    if ($running) { $running.WaitForExit(5000) | Out-Null }
}

$first = $samples[0]
$last = $samples[-1]
$elapsed = [Math]::Max(1, ((Get-Date $last.at) - (Get-Date $first.at)).TotalSeconds)
$cpuSeconds = [Math]::Max(0, $last.cpu - $first.cpu)
$averageCpuPercent = $cpuSeconds / $elapsed / [Environment]::ProcessorCount * 100
$cacheAfter = Get-DirectoryBytes $BundleCacheDirectory
$result = [pscustomobject]@{
    status = if ($samples.Count -ge 2 -and -not (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) { 'passed' } else { 'failed' }
    samples = $samples.Count
    elapsed_minutes = [Math]::Round($elapsed / 60, 2)
    average_cpu_percent = [Math]::Round($averageCpuPercent, 5)
    max_private_mb = [Math]::Round((($samples | Measure-Object -Property private -Maximum).Maximum) / 1MB, 2)
    private_delta_kb = [Math]::Round(($last.private - $first.private) / 1KB, 1)
    working_set_delta_kb = [Math]::Round(($last.working_set - $first.working_set) / 1KB, 1)
    handles_delta = $last.handles - $first.handles
    threads_delta = $last.threads - $first.threads
    bundle_cache_delta_bytes = $cacheAfter - $cacheBefore
}
if ($result.status -ne 'passed') { throw 'Watcher exited unexpectedly or produced too few samples.' }
if ($result.max_private_mb -ge 20) { throw 'Watcher private memory exceeded the 20 MB release budget.' }
if ($result.average_cpu_percent -ge 0.05) { throw 'Watcher average CPU exceeded the 0.05% release budget.' }
if ($result.bundle_cache_delta_bytes -ne 0) { throw 'Watcher created or expanded the .NET bundle cache.' }
$result | ConvertTo-Json
