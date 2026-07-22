# Privacy model

Codex Guardian is local-first and does not require a Guardian account.

## Data read

When quota is missing or expired at startup, or when the user explicitly refreshes, the desktop app may start a short-lived Codex app-server from a currently running `%LOCALAPPDATA%\OpenAI\Codex\bin\<version>\codex.exe` and invoke only `account/rateLimits/read`. Guardian does not open Codex authentication files or supply credentials. The response is parsed in memory and raw protocol output and stderr are not stored.

As a fallback, the provider scans recent `rollout-*.jsonl` files under `%USERPROFILE%\.codex\sessions` and inspects only `payload.rate_limits` fields:

- `used_percent`
- `window_minutes`
- `resets_at`
- `plan_type`

The provider opens files with shared read access so it does not block Codex.

## Data stored

Guardian stores local state under `%CODEX_GUARDIAN_HOME%\data` when that optional absolute-path override is set, otherwise under `%USERPROFILE%\.codex-guardian\data`:

- capture timestamp
- remaining percentages
- reset timestamps
- provider name
- window position and collapsed state
- local preferences such as refresh interval, strategy, theme, and retention period
- interface language and whether personalized analysis is enabled
- whether the optional follow-Codex startup watcher is enabled
- sanitized notification decisions (level, reason, outcome, and reset time)

Guardian does not store prompts, responses, code, project names, filenames, cookies, or authentication tokens.

History is retained for the configured 30, 90, 180, or 365 days, subject to a strict 16 MB file ceiling. When either limit is reached, compaction keeps the newest valid quota records. The notification decision log is separately capped at 512 KB and compacts to its newest 500 entries. Settings and window state are fixed-size JSON documents. Clearing history requires two explicit confirmations and empties the history file without removing settings or the application. Safe export contains the same normalized quota fields and a privacy notice.

The installed runtime is folder-based and creates no per-version .NET extraction cache. Release downloads use fixed filenames under `<home>\downloads`, so downloading a newer release overwrites that bounded staging slot instead of appending versioned archives indefinitely.

## Network behavior

Guardian contains no direct HTTP quota client. The bounded active refresh uses the already signed-in Codex app-server, which may contact OpenAI through Codex's existing connection. A successful startup query is not repeated by ordinary polling. Failed startup queries are limited to three attempts spaced at least ten seconds apart, manual refresh requests one additional attempt, and every attempt has an eight-second timeout. When active refresh is unavailable, Guardian falls back to local session metadata and never guesses a value.

The optional installer contacts only the GitHub API and release-asset URLs selected by the configured repository. It requires a matching SHA-256 file, rejects archive path traversal and symbolic links, and refuses archives with more than 2,000 files or more than 350 MB expanded content.

Theme rendering, task tracking, weekly reports, prediction, localization, and notification decisions all run locally. Disabling personalized analysis hides strategy, task-budget, and weekly-report features while leaving real-time quota and the timeline available. The optional weather effect from the early product plan is not implemented because it would require unrelated network or location data.

The optional follow-Codex watcher performs no network requests and writes no log or cache. It checks only local `ChatGPT.exe` executable paths and accepts paths inside the Windows `OpenAI.Codex_*` package. It does not inspect command contents, window text, prompts, account data, or unrelated process files. The watcher is disabled by default and uses only the current user's Windows startup entry when enabled.
