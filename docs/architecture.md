# Architecture

Codex Guardian separates data acquisition from decisions and presentation.

## Projects

- `CodexGuardian.Core`: domain records, monitor, predictor, and advisor.
- `CodexGuardian.Providers`: read-only quota sources and schema validation.
- `CodexGuardian.Storage`: sanitized JSONL history and notification-decision journal.
- `CodexGuardian.App`: Windows WPF widget, tray lifecycle, localization, and native/fallback notification presentation.
- `CodexGuardian.Cli`: safe provider diagnostics.
- `CodexGuardian.Tests`: unit and contract tests.

## Acquisition path

The WPF app uses a hybrid provider. Missing or expired startup data triggers one bounded read through the already running, signed-in Codex app-server; failures retry at most three times. Manual refresh requests one read. Validated results are cached in memory and merged per window with the local JSONL provider, while ordinary polling reads only local state. The diagnostic CLI deliberately retains the local-only provider.

## Failure policy

The system fails closed. A provider schema mismatch produces an unavailable state; it never re-labels a cached number as current. Storage failures do not interrupt live monitoring. Predictions require enough history and always expose confidence.

## Notification boundary

Core code decides whether a notification has value; the app only presents that decision. On supported Windows systems, Guardian uses the unpackaged Windows App SDK notification manager and action arguments parsed by a separately tested parser. If native notifications are unavailable or disabled by Windows, the app uses its local WPF fallback. Notification decisions are logged locally without prompts, responses, code, or filenames.
