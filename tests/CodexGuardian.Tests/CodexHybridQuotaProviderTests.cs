using CodexGuardian.Core;
using CodexGuardian.Providers;

namespace CodexGuardian.Tests;

public class CodexHybridQuotaProviderTests
{
    [Theory]
    [InlineData(@"C:\Users\test\AppData\Local\OpenAI\Codex\bin\version\codex.exe", true)]
    [InlineData(@"C:\Users\test\AppData\Local\OpenAI\Codex\codex.exe", false)]
    [InlineData(@"D:\OpenAI\Codex\bin\version\codex.exe", false)]
    [InlineData(@"C:\Users\test\AppData\Local\OpenAI\Codex\bin\version\other.exe", false)]
    public void RestrictsExecutableToRunningCodexBinPath(string path, bool expected)
    {
        Assert.Equal(expected, CodexAppServerQuotaProbe.IsTrustedCodexExecutablePath(
            path,
            @"C:\Users\test\AppData\Local"));
    }

    [Fact]
    public void ParsesCodexBucketFromAppServerResponse()
    {
        var now = new DateTimeOffset(2026, 7, 20, 8, 0, 0, TimeSpan.Zero);
        var response = """
            {"id":2,"result":{"rateLimits":{"primary":{"usedPercent":55,"windowDurationMins":300,"resetsAt":1784540000},"secondary":null,"planType":"plus"},"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":19,"windowDurationMins":10080,"resetsAt":1784962289},"secondary":null,"planType":"plus"}}}}
            """;

        Assert.True(AppServerRateLimitParser.TryParseResponse(response, now, out var snapshot));
        Assert.Null(snapshot!.FiveHour);
        Assert.Equal(81, snapshot.Weekly!.RemainingPercent);
        Assert.Equal(now, snapshot.WeeklyObservedAt);
        Assert.Equal("plus", snapshot.PlanType);
        Assert.Equal("Codex app-server rate limits", snapshot.Source);
    }

    [Theory]
    [InlineData("{\"id\":2,\"result\":{}}")]
    [InlineData("{\"id\":2,\"result\":{\"rateLimits\":{\"primary\":{\"usedPercent\":19,\"windowDurationMins\":10080,\"resetsAt\":null}}}}")]
    public void RejectsIncompleteAppServerResponse(string response)
    {
        Assert.False(AppServerRateLimitParser.TryParseResponse(response, DateTimeOffset.UtcNow, out _));
    }

    [Fact]
    public async Task ReplacesExpiredWindowAtStartupAndDoesNotProbeEveryPoll()
    {
        var root = Path.Combine(TestPaths.Root, "hybrid-session", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        var now = new DateTimeOffset(2026, 7, 20, 8, 0, 0, TimeSpan.Zero);
        await File.WriteAllTextAsync(
            Path.Combine(root, "rollout-stale.jsonl"),
            "{\"timestamp\":\"2026-07-20T05:00:00Z\",\"payload\":{\"rate_limits\":{\"primary\":{\"used_percent\":41,\"window_minutes\":10080,\"resets_at\":1784962289},\"secondary\":null,\"plan_type\":\"plus\"}}}" + Environment.NewLine);
        var clock = new MutableTimeProvider(now);
        var active = new FakeProbe(new(
            now,
            "active-test",
            null,
            new(19, 10080, DateTimeOffset.FromUnixTimeSeconds(1784962289)),
            DataFreshness.Fresh,
            "plus",
            null,
            now));
        var provider = new CodexHybridQuotaProvider(new(root, clock), active, clock);

        var first = await provider.ReadAsync();
        var second = await provider.ReadAsync();

        Assert.Equal(81, first.Snapshot!.Weekly!.RemainingPercent);
        Assert.Equal(DataFreshness.Fresh, first.Snapshot.GetWeeklyFreshness(now));
        Assert.Equal(1, active.ReadCount);
        Assert.Equal(81, second.Snapshot!.Weekly!.RemainingPercent);

        provider.RequestActiveRefresh();
        await provider.ReadAsync();
        Assert.Equal(2, active.ReadCount);
    }

    [Fact]
    public async Task LimitsAutomaticStartupRetries()
    {
        var root = Path.Combine(TestPaths.Root, "hybrid-missing", Guid.NewGuid().ToString("N"));
        var clock = new MutableTimeProvider(new(2026, 7, 20, 8, 0, 0, TimeSpan.Zero));
        var active = new FakeProbe(null);
        var provider = new CodexHybridQuotaProvider(new(root, clock), active, clock);

        await provider.ReadAsync();
        await provider.ReadAsync();
        Assert.Equal(1, active.ReadCount);

        clock.Now = clock.Now.AddSeconds(11);
        await provider.ReadAsync();
        clock.Now = clock.Now.AddSeconds(11);
        await provider.ReadAsync();
        clock.Now = clock.Now.AddSeconds(11);
        await provider.ReadAsync();

        Assert.Equal(3, active.ReadCount);
    }

    private sealed class FakeProbe(QuotaSnapshot? snapshot) : ICodexQuotaProbe
    {
        public int ReadCount { get; private set; }

        public Task<QuotaSnapshot?> ReadAsync(CancellationToken cancellationToken = default)
        {
            ReadCount++;
            return Task.FromResult(snapshot);
        }
    }

    private sealed class MutableTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = now;
        public override DateTimeOffset GetUtcNow() => Now;
    }
}
