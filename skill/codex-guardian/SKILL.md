---
name: codex-guardian
description: Install, launch, configure, diagnose, or repair the Codex Guardian Windows quota companion. Use when a user asks to install Guardian, show Codex five-hour or weekly quota on the desktop, troubleshoot NO DATA/STALE/EXPIRED status, check local quota metadata compatibility, change Guardian startup behavior, or repair an existing installation.
---

# Codex Guardian

Manage the local-first Guardian desktop app without reading credentials or exposing Codex session contents.

## Choose a workflow

- For status or troubleshooting, run `scripts/diagnose-guardian.ps1` first.
- Before first install, run `scripts/detect-environment.ps1`.
- For a local release package, run `scripts/install-guardian.ps1 -PackagePath <zip>`.
- For a published release, run `scripts/install-guardian.ps1 -Repository <owner/repo>`.
- For repair, run `scripts/repair-guardian.ps1` and follow its reported next action.
- For uninstall requests, run `scripts/uninstall-guide.ps1`; it reports scope but deletes nothing.
- For privacy or schema questions, read `references/provider-and-privacy.md`.
- For error-specific recovery, read `references/troubleshooting.md`.

## Diagnose

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/diagnose-guardian.ps1
```

Report the safe summary only. Never print or attach raw rollout JSONL, `auth.json`, prompts, code, cookies, or tokens.

Interpret results:

- `healthy`: Guardian can read a validated local quota snapshot.
- `no_session_directory`: Codex has not created local sessions for this profile.
- `metadata_not_found`: Ask the user to run one Codex task, then diagnose again.
- `schema_mismatch`: The installed provider may need an update.
- `app_not_installed`: Install Guardian.

## Install

Prefer a user-provided package or a published GitHub Release. Do not install from an unverified arbitrary URL.

Local package:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-guardian.ps1 -PackagePath C:\path\CodexGuardian-win-x64.zip
```

Published release:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-guardian.ps1 -Repository owner/CodexGuardian
```

Resolve the Guardian home with `scripts/resolve-guardian-home.ps1`: use the optional absolute user environment variable `CODEX_GUARDIAN_HOME`, otherwise `%USERPROFILE%\.codex-guardian`. Install under `<home>\app`, keep state under `<home>\data`, direct `DOTNET_BUNDLE_EXTRACT_BASE_DIR` to `<home>\bundle-cache` for the launched process, preserve settings/history, and launch Guardian. This non-AppData location avoids package-context virtualization when the Skill runs from Codex. Do not change machine-wide security settings.

## Configure

Use Guardian's Settings window for refresh interval, always-on-top, start-with-Windows, notifications, do-not-disturb, reduced motion, interface language (full Chinese or full English), and optional personalized analysis. Disabling personalized analysis must not disable real-time quota or the timeline. Do not edit the JSON settings file while Guardian is running.

## Repair

Run the repair script. Allow it to relaunch or reinstall only within the Guardian install directory. Preserve `settings.json`, `window-state.json`, and `quota-history.jsonl`.

## Destructive actions

Never remove Guardian files, settings, history, startup entries, or installation directories without the user's explicit confirmation for that exact deletion.
