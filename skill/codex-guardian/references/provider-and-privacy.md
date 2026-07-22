# Provider and privacy

Guardian's desktop provider may use the running `%LOCALAPPDATA%\OpenAI\Codex\bin\<version>\codex.exe` app-server for the fixed read-only `account/rateLimits/read` method when startup data is absent or expired, or when the user manually refreshes. It never reads or supplies credentials, and raw protocol output is not stored. The Codex child may contact OpenAI using the existing sign-in.

The fallback and diagnostic provider scans recent `%USERPROFILE%\.codex\sessions\**\rollout-*.jsonl` files and reads only `payload.rate_limits`.

Allowed fields:

- primary/secondary `used_percent`
- `window_minutes`
- `resets_at`
- `plan_type`

Never read or copy `%USERPROFILE%\.codex\auth.json`. Never return raw session lines. Diagnostic output may contain remaining percentages, reset timestamps, freshness, provider state, and app version only.

The Codex app-server method and session JSONL are compatibility surfaces. Treat null, missing, malformed, or out-of-range fields as unavailable. Never label cached data as live after the freshness window expires.

The optional follow-Codex watcher is local-only. It may inspect executable paths for running `ChatGPT.exe` processes solely to verify the packaged `OpenAI.Codex_*\\app\\ChatGPT.exe` path. It must not inspect command contents, window titles, prompts, or unrelated process files, and it must not create logs or network traffic.
