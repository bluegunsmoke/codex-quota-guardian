namespace CodexGuardian.Core;

public sealed record TaskBudgetEstimate(
    int MinimumPercent,
    int MaximumPercent,
    PredictionConfidence Confidence,
    string Basis);

public sealed record TaskQuotaSummary(
    DateTimeOffset StartedAt,
    DateTimeOffset FinishedAt,
    int FiveHourConsumedPercent,
    int WeeklyConsumedPercent,
    string Explanation);

public static class TaskBudgetAdvisor
{
    public static TaskBudgetEstimate Estimate(
        BurnRatePrediction prediction,
        TimeSpan plannedDuration,
        QuotaStrategyPolicy policy)
    {
        ArgumentOutOfRangeException.ThrowIfLessThanOrEqual(plannedDuration, TimeSpan.Zero);
        if (prediction.Confidence == PredictionConfidence.None || prediction.PercentPerHour <= 0)
            return new(0, 0, PredictionConfidence.None, "Not enough local history to estimate a task budget.");

        var expected = prediction.PercentPerHour * plannedDuration.TotalHours;
        var spread = prediction.Confidence switch
        {
            PredictionConfidence.High => 0.2,
            PredictionConfidence.Medium => 0.4,
            _ => 0.75,
        };
        var minimum = Math.Max(1, (int)Math.Floor(expected * (1 - spread)));
        var maximum = Math.Max(minimum, (int)Math.Ceiling(expected * (1 + spread)));
        return new(minimum, maximum, prediction.Confidence,
            $"Based on {prediction.SampleCount} local samples at {prediction.PercentPerHour:F1}% per hour; keep the {policy.FiveHourReservePercent}% reserve intact.");
    }

    public static TaskQuotaSummary Summarize(QuotaSnapshot before, QuotaSnapshot after)
    {
        if (after.CapturedAt < before.CapturedAt) throw new ArgumentException("The final snapshot must not predate the initial snapshot.", nameof(after));
        var fiveHourConsumed = before.FiveHour is { } beforeFiveHour &&
                               after.FiveHour is { } afterFiveHour &&
                               beforeFiveHour.ResetsAt == afterFiveHour.ResetsAt
            ? Math.Max(0, beforeFiveHour.RemainingPercent - afterFiveHour.RemainingPercent)
            : 0;
        var weeklyConsumed = before.Weekly is { } beforeWeekly &&
                             after.Weekly is { } afterWeekly &&
                             beforeWeekly.ResetsAt == afterWeekly.ResetsAt
            ? Math.Max(0, beforeWeekly.RemainingPercent - afterWeekly.RemainingPercent)
            : 0;
        var resetNote = before.FiveHour is { } startFiveHour &&
                        after.FiveHour is { } endFiveHour &&
                        startFiveHour.ResetsAt == endFiveHour.ResetsAt
            ? ""
            : " The five-hour window reset during this task or was unavailable, so its delta is not attributed.";
        return new(before.CapturedAt, after.CapturedAt, fiveHourConsumed, weeklyConsumed,
            $"Task used {fiveHourConsumed}% of the current five-hour window and {weeklyConsumed}% of the weekly quota.{resetNote}");
    }
}
