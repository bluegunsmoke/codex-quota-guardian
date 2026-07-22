# Data-source validation

Guardian's desktop provider first requests the current rate-limit snapshot from the running Codex app-server, then merges it per window with validated `payload.rate_limits` events from recent local Codex rollout JSONL files.

Validated fields:

- five-hour `used_percent`, window duration, and reset timestamp;
- weekly `used_percent`, window duration, and reset timestamp;
- optional plan type;
- event capture timestamp used to calculate freshness.

The app-server response accepts only the declared `rateLimitsByLimitId.codex` bucket (preferred) or its compatible `rateLimits` fallback, with `usedPercent`, `windowDurationMins`, and `resetsAt`. Values outside the same domain rules are rejected. Only 300-minute and 10,080-minute windows map to Guardian's five-hour and weekly tracks.

Observed compatibility details:

- percentages may be JSON integers or decimals;
- partial events may contain `null` primary or secondary windows;
- files may be actively written while Guardian reads them;
- malformed and incomplete lines must be skipped;
- no valid complete event results in `NO DATA`, never a fabricated value.

The provider opens files read-only with shared read/write access. It never reads `auth.json`, cookies, passwords, API tokens, prompts, responses, or source files. The diagnostic CLI and Skill report only the normalized quota summary.

Both protocol and JSONL shapes are compatibility surfaces. A future Codex schema change may require a provider update; Guardian fails closed when validation no longer succeeds.
