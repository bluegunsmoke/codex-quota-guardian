# Known limitations

- Windows is the only supported desktop platform in the first release.
- Immediate refresh requires a signed-in, running Codex desktop app. If the active query is unavailable, Guardian falls back to local session metadata and may require one recent Codex task.
- The Codex app-server protocol and local session schema are compatibility surfaces and may change; Guardian reports `NO DATA` instead of guessing.
- Codex may return only one quota window. Guardian displays each window independently, so an unavailable five-hour window remains gray even when weekly quota is current.
- Forecasts learn only while Guardian records local quota snapshots. Cold starts intentionally avoid precise claims.
- Fullscreen, OBS, PowerPoint, and user-enabled do-not-disturb states are detected without reading window content; other presentation tools may not yet be recognized.
- Guardian is distributed unsigned during local release-candidate testing. Windows may show the publisher as unknown.
- The portable ZIP expands to roughly 205 MB because it carries the .NET Desktop and Windows App SDK runtimes. All files in the extracted folder are required; the launcher is not a standalone EXE.
- Native notification delivery depends on Windows notification settings. Guardian falls back to its own local notification window when native delivery is unavailable; action buttons require a running resident instance.
- Forecast ranges are estimates derived from recent local history, not account guarantees. Low-confidence forecasts deliberately show wider uncertainty or no future curve.
- The Skill installs under `%CODEX_GUARDIAN_HOME%` when configured, otherwise `%USERPROFILE%\.codex-guardian`, so launches originating from a packaged Codex process do not place app state in that parent package's private AppData cache. Existing pre-release LocalAppData state is copied forward without deleting the old files.
- Seasonal or network-backed weather effects are intentionally excluded: they would add network/privacy cost without improving quota decisions.
