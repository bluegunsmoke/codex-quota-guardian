# Release readiness gates

Guardian is ready for public release only after every gate below has current evidence.

## Automated gates

- Release restore, build, and tests pass with warnings treated as errors.
- Provider parser covers decimals, null windows, malformed input, stale data, and failure recovery.
- Predictor covers cold start, reset precedence, duplicate timestamps, and long data gaps.
- Advisor covers the one-minute rule, confidence, quiet contexts, cooldown, worsening risk, and silence-until-reset.
- Storage covers corruption recovery, restart deduplication, retention, concurrent writes, safe export, and explicit clear behavior.
- Skill structure and all PowerShell scripts validate.
- English and Chinese resource keys, format placeholders, and XAML references validate.
- Application source contains no direct HTTP quota client, the active provider exposes only the fixed bounded `account/rateLimits/read` probe, and Skill scripts contain no deletion command.
- A self-contained, folder-based `win-x64` candidate package is produced with a SHA-256 checksum.
- The candidate contains no user data or debug symbols, has no known vulnerable NuGet dependency, stays below the package-size budgets, and is not a self-extracting single-file bundle.
- The optional follow-Codex watcher is below 15 MB, defaults off, has no network/log/cache path, and passes the 30-minute watcher soak with private memory below 20 MB and average CPU below 0.05%.

Run all automated gates:

```powershell
.\scripts\run-release-audit.ps1
```

## Desktop gates

- Main capsule, settings, dashboard, tray, notification, theme, and collapse states are visually inspected.
- Switching between full English and full Chinese updates both static and dynamic text without restarting.
- Keyboard focus and timeline cursor work without a mouse.
- Per-monitor V2 DPI manifest is embedded.
- Position and settings survive restart; out-of-bounds positions are rejected.
- Candidate remains responsive during the automated residency soak.
- Follow-Codex startup launches and refreshes once per Codex lifecycle, respects a manual Guardian exit, and fully stops/removes its user startup entry when disabled.

## Human gate

The maintainer completes `docs/local-test-checklist.md` on the packaged executable. No GitHub repository, push, tag, or release is created before that explicit confirmation.
