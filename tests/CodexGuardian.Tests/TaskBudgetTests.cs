using CodexGuardian.Core;

namespace CodexGuardian.Tests;

public class TaskBudgetTests
{
    [Fact]
    public void EstimateIncludesRangeConfidenceAndBasis()
    {
        var result = TaskBudgetAdvisor.Estimate(
            new(10, null, PredictionConfidence.Medium, 8),
            TimeSpan.FromHours(1),
            QuotaStrategyPolicy.For(QuotaStrategyMode.Balanced));

        Assert.Equal(6, result.MinimumPercent);
        Assert.Equal(14, result.MaximumPercent);
        Assert.Equal(PredictionConfidence.Medium, result.Confidence);
        Assert.Contains("8 local samples", result.Basis, StringComparison.Ordinal);
    }

    [Fact]
    public void ColdStartDoesNotInventBudget()
    {
        var result = TaskBudgetAdvisor.Estimate(
            new(0, null, PredictionConfidence.None, 0),
            TimeSpan.FromHours(1),
            QuotaStrategyPolicy.For(QuotaStrategyMode.Balanced));

        Assert.Equal(0, result.MaximumPercent);
        Assert.Equal(PredictionConfidence.None, result.Confidence);
    }

    [Fact]
    public void SummaryDoesNotAttributeConsumptionAcrossReset()
    {
        var now = DateTimeOffset.UtcNow;
        var before = CreateSnapshot(now, 20, now.AddMinutes(5));
        var after = CreateSnapshot(now.AddMinutes(20), 98, now.AddHours(5));

        var result = TaskBudgetAdvisor.Summarize(before, after);

        Assert.Equal(0, result.FiveHourConsumedPercent);
        Assert.Contains("reset during this task", result.Explanation, StringComparison.OrdinalIgnoreCase);
    }

    private static QuotaSnapshot CreateSnapshot(DateTimeOffset capturedAt, int remaining, DateTimeOffset resetAt) => new(
        capturedAt,
        "test",
        new(100 - remaining, 300, resetAt),
        new(30, 10080, capturedAt.AddDays(5)),
        DataFreshness.Fresh);
}
