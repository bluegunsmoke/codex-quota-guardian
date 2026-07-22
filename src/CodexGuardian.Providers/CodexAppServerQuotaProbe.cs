using System.ComponentModel;
using System.Diagnostics;
using System.Text.Json;
using CodexGuardian.Core;

namespace CodexGuardian.Providers;

internal interface ICodexQuotaProbe
{
    Task<QuotaSnapshot?> ReadAsync(CancellationToken cancellationToken = default);
}

public sealed class CodexHybridQuotaProvider : IQuotaProvider
{
    private const int MaximumStartupAttempts = 3;
    private static readonly TimeSpan StartupRetryDelay = TimeSpan.FromSeconds(10);
    private readonly CodexSessionQuotaProvider _sessionProvider;
    private readonly ICodexQuotaProbe _activeProbe;
    private readonly TimeProvider _timeProvider;
    private QuotaSnapshot? _lastActiveSnapshot;
    private DateTimeOffset _nextStartupAttemptAt = DateTimeOffset.MinValue;
    private int _startupAttempts;
    private bool _startupProbeComplete;
    private bool _forceActiveRead;

    public CodexHybridQuotaProvider()
        : this(new CodexSessionQuotaProvider(), new CodexAppServerQuotaProbe(), TimeProvider.System)
    {
    }

    internal CodexHybridQuotaProvider(
        CodexSessionQuotaProvider sessionProvider,
        ICodexQuotaProbe activeProbe,
        TimeProvider timeProvider)
    {
        _sessionProvider = sessionProvider;
        _activeProbe = activeProbe;
        _timeProvider = timeProvider;
    }

    public string Name => "Codex app-server with local session fallback";

    public void RequestActiveRefresh() => _forceActiveRead = true;

    public async Task<QuotaReadResult> ReadAsync(CancellationToken cancellationToken = default)
    {
        var localResult = await _sessionProvider.ReadAsync(cancellationToken).ConfigureAwait(false);
        var now = _timeProvider.GetUtcNow();
        if (ShouldRunActiveProbe(localResult.Snapshot, now))
        {
            _forceActiveRead = false;
            var activeSnapshot = await _activeProbe.ReadAsync(cancellationToken).ConfigureAwait(false);
            if (activeSnapshot is not null)
            {
                _lastActiveSnapshot = activeSnapshot;
                _startupProbeComplete = true;
            }
            else
            {
                _startupAttempts++;
                _nextStartupAttemptAt = now + StartupRetryDelay;
            }
        }

        var merged = CodexSessionQuotaProvider.Merge(localResult.Snapshot, _lastActiveSnapshot, now);
        return merged is null ? localResult : QuotaReadResult.Success(merged);
    }

    private bool ShouldRunActiveProbe(QuotaSnapshot? localSnapshot, DateTimeOffset now)
    {
        if (_forceActiveRead) return true;
        if (_startupProbeComplete || _startupAttempts >= MaximumStartupAttempts || now < _nextStartupAttemptAt)
            return false;
        if (localSnapshot is null) return true;

        var hasCurrentWindows = localSnapshot.GetFiveHourFreshness(now) == DataFreshness.Fresh &&
            localSnapshot.GetWeeklyFreshness(now) == DataFreshness.Fresh;
        if (hasCurrentWindows)
        {
            _startupProbeComplete = true;
            return false;
        }
        return true;
    }
}

internal sealed class CodexAppServerQuotaProbe(TimeSpan? timeout = null) : ICodexQuotaProbe
{
    private readonly TimeSpan _timeout = timeout ?? TimeSpan.FromSeconds(8);

    public async Task<QuotaSnapshot?> ReadAsync(CancellationToken cancellationToken = default)
    {
        var executable = FindRunningCodexExecutable();
        if (executable is null) return null;

        using var timeoutSource = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeoutSource.CancelAfter(_timeout);
        using var process = new Process
        {
            StartInfo = new()
            {
                FileName = executable,
                WorkingDirectory = Path.GetDirectoryName(executable)!,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
            },
        };
        process.StartInfo.ArgumentList.Add("app-server");
        process.StartInfo.ArgumentList.Add("--stdio");

        Task<string>? stderrDrain = null;
        var started = false;
        try
        {
            if (!process.Start()) return null;
            started = true;
            stderrDrain = process.StandardError.ReadToEndAsync(timeoutSource.Token);
            await SendAsync(process, new
            {
                id = 1,
                method = "initialize",
                @params = new
                {
                    clientInfo = new { name = "codex-guardian", version = "1.0" },
                    capabilities = new { experimentalApi = true },
                },
            }, timeoutSource.Token).ConfigureAwait(false);

            var initialized = false;
            while (await process.StandardOutput.ReadLineAsync(timeoutSource.Token).ConfigureAwait(false) is { } line)
            {
                using var document = JsonDocument.Parse(line);
                var root = document.RootElement;
                if (!root.TryGetProperty("id", out var id) || !id.TryGetInt32(out var requestId)) continue;
                if (root.TryGetProperty("error", out _)) return null;

                if (requestId == 1 && !initialized)
                {
                    await SendAsync(process, new { method = "initialized" }, timeoutSource.Token).ConfigureAwait(false);
                    await SendAsync(process, new { id = 2, method = "account/rateLimits/read", @params = (object?)null }, timeoutSource.Token).ConfigureAwait(false);
                    initialized = true;
                }
                else if (requestId == 2)
                {
                    return AppServerRateLimitParser.TryParseResponse(line, DateTimeOffset.UtcNow, out var snapshot)
                        ? snapshot
                        : null;
                }
            }
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return null;
        }
        catch (Exception exception) when (exception is Win32Exception or IOException or InvalidOperationException or JsonException)
        {
            return null;
        }
        finally
        {
            if (started) await StopProcessAsync(process).ConfigureAwait(false);
            if (stderrDrain is not null)
            {
                try { await stderrDrain.WaitAsync(TimeSpan.FromSeconds(1), CancellationToken.None).ConfigureAwait(false); }
                catch (Exception exception) when (exception is TimeoutException or OperationCanceledException) { }
            }
        }
        return null;
    }

    private static async Task SendAsync(Process process, object message, CancellationToken cancellationToken)
    {
        var json = JsonSerializer.Serialize(message);
        await process.StandardInput.WriteLineAsync(json.AsMemory(), cancellationToken).ConfigureAwait(false);
        await process.StandardInput.FlushAsync(cancellationToken).ConfigureAwait(false);
    }

    private static async Task StopProcessAsync(Process process)
    {
        if (!process.HasExited)
        {
            process.StandardInput.Close();
            try
            {
                await process.WaitForExitAsync().WaitAsync(TimeSpan.FromSeconds(1)).ConfigureAwait(false);
            }
            catch (TimeoutException)
            {
                process.Kill(entireProcessTree: true);
                await process.WaitForExitAsync().ConfigureAwait(false);
            }
        }
    }

    private static string? FindRunningCodexExecutable()
    {
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        Process[] processes;
        try { processes = Process.GetProcessesByName("codex"); }
        catch (InvalidOperationException) { return null; }

        try
        {
            foreach (var process in processes)
            {
                try
                {
                    var path = process.MainModule?.FileName;
                    if (path is null) continue;
                    var fullPath = Path.GetFullPath(path);
                    if (IsTrustedCodexExecutablePath(fullPath, localAppData))
                        return fullPath;
                }
                catch (Exception exception) when (exception is Win32Exception or InvalidOperationException or NotSupportedException)
                {
                    // Ignore inaccessible or exiting processes; never fall back to an untrusted path.
                }
            }
        }
        finally
        {
            foreach (var process in processes) process.Dispose();
        }
        return null;
    }

    internal static bool IsTrustedCodexExecutablePath(string? executablePath, string localAppData)
    {
        if (string.IsNullOrWhiteSpace(executablePath) || string.IsNullOrWhiteSpace(localAppData)) return false;
        try
        {
            var trustedRoot = Path.GetFullPath(Path.Combine(localAppData, "OpenAI", "Codex", "bin")) + Path.DirectorySeparatorChar;
            var fullPath = Path.GetFullPath(executablePath);
            return fullPath.StartsWith(trustedRoot, StringComparison.OrdinalIgnoreCase) &&
                string.Equals(Path.GetFileName(fullPath), "codex.exe", StringComparison.OrdinalIgnoreCase);
        }
        catch (Exception exception) when (exception is ArgumentException or NotSupportedException or PathTooLongException)
        {
            return false;
        }
    }
}

public static class AppServerRateLimitParser
{
    public static bool TryParseResponse(string response, DateTimeOffset now, out QuotaSnapshot? snapshot)
    {
        snapshot = null;
        try
        {
            using var document = JsonDocument.Parse(response);
            var root = document.RootElement;
            if (!root.TryGetProperty("result", out var result) || result.ValueKind != JsonValueKind.Object)
                return false;

            JsonElement limits;
            if (result.TryGetProperty("rateLimitsByLimitId", out var byId) &&
                byId.ValueKind == JsonValueKind.Object &&
                byId.TryGetProperty("codex", out var codexLimits) &&
                codexLimits.ValueKind == JsonValueKind.Object)
                limits = codexLimits;
            else if (result.TryGetProperty("rateLimits", out var legacyLimits) && legacyLimits.ValueKind == JsonValueKind.Object)
                limits = legacyLimits;
            else
                return false;

            QuotaWindow? fiveHour = null;
            QuotaWindow? weekly = null;
            foreach (var propertyName in new[] { "primary", "secondary" })
            {
                if (!limits.TryGetProperty(propertyName, out var element) || !TryReadWindow(element, out var window))
                    continue;
                if (window!.WindowMinutes == 300) fiveHour = window;
                else if (window.WindowMinutes == 10080) weekly = window;
            }
            if (fiveHour is null && weekly is null) return false;

            var planType = limits.TryGetProperty("planType", out var plan) && plan.ValueKind == JsonValueKind.String
                ? plan.GetString()
                : null;
            snapshot = new(
                now,
                "Codex app-server rate limits",
                fiveHour,
                weekly,
                DataFreshness.Fresh,
                planType,
                fiveHour is null ? null : now,
                weekly is null ? null : now);
            return true;
        }
        catch (Exception exception) when (exception is JsonException or InvalidOperationException or ArgumentOutOfRangeException)
        {
            return false;
        }
    }

    private static bool TryReadWindow(JsonElement element, out QuotaWindow? window)
    {
        window = null;
        if (element.ValueKind != JsonValueKind.Object ||
            !element.TryGetProperty("usedPercent", out var usedElement) ||
            !element.TryGetProperty("windowDurationMins", out var minutesElement) ||
            !element.TryGetProperty("resetsAt", out var resetElement) ||
            !usedElement.TryGetInt32(out var used) ||
            !minutesElement.TryGetInt32(out var minutes) ||
            !resetElement.TryGetInt64(out var resetUnix) ||
            used is < 0 or > 100 ||
            minutes <= 0)
            return false;

        window = new(used, minutes, DateTimeOffset.FromUnixTimeSeconds(resetUnix));
        return true;
    }
}
