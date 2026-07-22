# Codex Guardian

Codex Guardian is a quiet, local-first Windows companion that shows the remaining Codex five-hour and weekly quota without repeatedly opening settings.

> Project status: public Windows release candidate. Download [v1.0.0-rc.14](https://github.com/bluegunsmoke/codex-quota-guardian/releases/tag/v1.0.0-rc.14).

## Why Guardian

- Shows remaining quota and reset time in a small always-on-top capsule.
- Reads current quota through the already signed-in Codex app when available, with local session metadata as a fallback; it never reads account cookies, passwords, or authentication tokens.
- Distinguishes live, stale, expired, and unavailable data.
- Keeps sanitized local history for burn-rate prediction.
- Follows a quiet-by-default notification model.

## Current capabilities

- Current five-hour and weekly quota from a bounded read-only Codex app-server query, with `%USERPROFILE%\.codex\sessions` as a local fallback.
- Replaceable quota-provider contract.
- Borderless expandable WPF widget with live freshness state.
- System tray, manual refresh, auto refresh, and window-state persistence.
- Optional follow-Codex startup through a small local watcher; it is off by default and mutually exclusive with starting Guardian immediately at Windows sign-in.
- Local JSONL history containing quota numbers only.
- Explicit two-step history clearing and sanitized local export.
- Cold-start-safe predictor and action-value advisor.
- Interactive quota timeline with confidence bands plus paused, light, current, and high-load scenarios.
- Multi-window quota trends and local prediction backtesting.
- Sprint, balanced, and conservative reserve strategies.
- Privacy-safe task budget, before/after summary, and seven-day report.
- Quiet four-level notification policy with cooldown, context suppression, silence-until-reset, and native Windows action buttons.
- Ten palettes with an inline/live preview, plus independently selectable petals, snow, fireflies, and starfall effects that honor reduced-motion and hidden-window states.
- Immediate full Chinese or full English UI switching.
- Optional personalized analysis; real-time quota and timeline remain available when it is disabled.
- Diagnostic CLI with safe JSON output.

## Privacy

Guardian requests only the current rate-limit object from the already signed-in Codex app and otherwise reads that object from local Codex session events. It does not read or persist prompts, responses, source code, filenames, cookies, or authentication tokens. The short-lived Codex child may contact OpenAI using Codex's existing sign-in. See [docs/privacy.md](docs/privacy.md).

## Requirements

- Windows 10 version 2004 (build 19041) or later, or Windows 11.
- .NET 8 Desktop Runtime for framework-dependent builds.
- The signed-in Codex desktop app running for immediate refresh, or recent local Codex session events for fallback data.

The packaged `win-x64` build carries both .NET and Windows App SDK dependencies and does not require a separate runtime installation. Source builds require the .NET 8 SDK.

## Install

Download the Windows x64 ZIP and its `.sha256` file from [v1.0.0-rc.14](https://github.com/bluegunsmoke/codex-quota-guardian/releases/tag/v1.0.0-rc.14), verify the checksum, extract the complete ZIP, and run `CodexGuardian.App.exe`. Guardian installs no service and requests no administrator permission. At startup when data is absent or stale, and on manual refresh, Guardian can briefly invoke the already signed-in Codex app-server for one fixed read-only quota query; Codex may contact OpenAI. Regular polling remains local. Enabling “Start Guardian with Codex” adds one current-user `Run` entry for the bundled `CodexGuardian.Watcher.exe`; disabling it removes that entry and signals the watcher to exit.

Set the optional user environment variable `CODEX_GUARDIAN_HOME` to an absolute path when the application and data must live on another drive. The Skill installs the complete application folder under `<home>\app` and stores local state under `<home>\data`; without an override, the home is `%USERPROFILE%\.codex-guardian`. The WPF application is deliberately folder-based rather than a self-extracting single EXE, so launching it does not create a per-version .NET bundle cache. Its optional trimmed watcher is a separate 12 MB-class executable and is verified not to expand the bundle cache. Keep all extracted files beside `CodexGuardian.App.exe`.

The bundled Skill can install a provided package without launching it:

```powershell
.\skill\codex-guardian\scripts\install-guardian.ps1 `
  -PackagePath D:\path\CodexGuardian-local-test-win-x64.zip `
  -NoLaunch
```

## Build

```powershell
dotnet restore CodexGuardian.sln
dotnet build CodexGuardian.sln --configuration Release --no-restore
dotnet test tests\CodexGuardian.Tests\CodexGuardian.Tests.csproj --configuration Release --no-build
```

Source restores use the ignored repository-local `work/.nuget/packages` cache. This keeps Guardian build dependencies on the drive that contains the checkout and prevents unexpected system-drive growth. It does not affect ZIP users or the installed application.

Run the full release audit:

```powershell
.\scripts\run-release-audit.ps1
```

Run the widget:

```powershell
dotnet run --project src\CodexGuardian.App\CodexGuardian.App.csproj
```

Inspect only the current quota metadata:

```powershell
dotnet run --project src\CodexGuardian.Cli\CodexGuardian.Cli.csproj
```

## Compatibility note

The Codex app-server rate-limit method and session-file schema are compatibility surfaces. Guardian validates both and fails closed when fields are absent or invalid. A Codex update may require a provider update; the UI will show `NO DATA` instead of presenting an old value as live.

## Package size

The `win-x64` ZIP is about 80 MB and expands to about 205 MB because it includes the .NET Desktop and Windows App SDK runtimes. This trades a larger download for zero prerequisite installation and avoids the repeated extraction-cache growth caused by a single-file self-contained executable.

Guardian's writable footprint is bounded: quota history is capped at 16 MB, notification decisions at 512 KB, and release downloads reuse one fixed staging filename. A standard installed copy therefore stays near 205 MB plus at most roughly 17 MB of application data; an installer-managed download slot can temporarily retain one additional ZIP within the 120 MB release budget.

## Architecture

```text
Codex app-server read + local session fallback -> Provider -> Monitor -> Widget
                                      -> History -> Predictor -> Advisor
```

See [architecture](docs/architecture.md), [provider contract](docs/provider-contract.md), [data-source validation](docs/data-source-validation.md), [known limitations](docs/known-limitations.md), and [release gates](docs/release-readiness.md).

## Contributing

Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a change.

## License

MIT. See [LICENSE](LICENSE).

## Trademark notice

Codex Guardian is an independent community project. It is not affiliated with, endorsed by, or sponsored by OpenAI. OpenAI and Codex are trademarks of their respective owner.
