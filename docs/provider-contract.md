# Quota provider contract

Every provider implements `IQuotaProvider.ReadAsync` and returns either a validated `QuotaSnapshot` or a typed failure.

## Required invariants

- Used percentages are finite values from 0 through 100.
- Window duration is positive.
- Reset timestamps are valid Unix timestamps.
- Source identifies the provider without exposing a path or account identifier.
- Missing, null, partial, or malformed windows are rejected.
- Provider errors are returned as data and do not crash the app.

## Freshness

- Fresh: captured no more than five minutes ago.
- Stale: older than five minutes but no more than one hour.
- Expired: older than one hour.
- Unavailable: no validated snapshot.

The UI must not label stale or expired data as live.

## Desktop hybrid provider

The desktop app first merges validated local session metadata with the newest successful active quota snapshot on a per-window basis. A newer five-hour window must not be discarded merely because only a weekly window was returned, and vice versa. Startup probing occurs only while a required window is missing or expired, stops after success, and is capped at three failures. Manual refresh can request one additional probe; ordinary periodic polling remains local.

The CLI provider remains local-only and reads session JSONL. This keeps diagnostics usable offline and prevents a diagnostic command from silently initiating an account request.
