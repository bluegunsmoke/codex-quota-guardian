using System.Text.Json;
using CodexGuardian.Providers;

var provider = new CodexSessionQuotaProvider();
var result = await provider.ReadAsync();

if (result.Snapshot is not { } snapshot)
{
    Console.Error.WriteLine($"{result.ErrorCode}: {result.Message}");
    return 1;
}

var output = new
{
    source = snapshot.Source,
    captured_at = snapshot.CapturedAt,
    freshness = snapshot.Freshness.ToString().ToLowerInvariant(),
    plan = snapshot.PlanType,
    five_hour = snapshot.FiveHour is { } fiveHour ? new
    {
        remaining_percent = fiveHour.RemainingPercent,
        resets_at = fiveHour.ResetsAt,
        observed_at = snapshot.FiveHourObservedAt,
        freshness = snapshot.GetFiveHourFreshness(DateTimeOffset.UtcNow).ToString().ToLowerInvariant(),
    } : null,
    weekly = snapshot.Weekly is { } weekly ? new
    {
        remaining_percent = weekly.RemainingPercent,
        resets_at = weekly.ResetsAt,
        observed_at = snapshot.WeeklyObservedAt,
        freshness = snapshot.GetWeeklyFreshness(DateTimeOffset.UtcNow).ToString().ToLowerInvariant(),
    } : null,
};

Console.WriteLine(JsonSerializer.Serialize(output, JsonDefaults.Indented));
return 0;

internal static class JsonDefaults
{
    public static JsonSerializerOptions Indented { get; } = new() { WriteIndented = true };
}
