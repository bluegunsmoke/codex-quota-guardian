# Codex Guardian 1.0.0-rc.14 release audit

Date: 2026-07-20 (Asia/Shanghai)

## Scope

This candidate fixes startup quota freshness without requiring a new task. The WPF app uses a bounded active read through the already signed-in Codex app-server and retains local session JSONL as a per-window fallback. The diagnostic CLI remains local-only.

## Automated gates

- `dotnet format --verify-no-changes --no-restore`: passed.
- Release build: passed with 0 warnings and 0 errors.
- Tests: 92 passed, 0 failed, 0 skipped.
- Known vulnerable direct or transitive NuGet dependencies: 0.
- English/Chinese localization, Skill validation, and installer safety fixtures: passed.
- Active-provider source gate: exactly one account method, `account/rateLimits/read`; no credential field reference and no direct HTTP/socket quota client.
- Candidate: 544 files, 216.30 MB expanded, 85.66 MB ZIP.
- Launcher: 0.20 MB. Follow-Codex watcher: 11.56 MB.

## Active-refresh safety and resource evidence

- Startup probing occurs only when a quota window is absent or expired; a successful startup read stops further automatic probes.
- Failed startup reads are capped at three attempts separated by at least 10 seconds. Manual refresh requests one additional read. Each probe times out after 8 seconds.
- Only a currently running `codex.exe` normalized beneath `%LOCALAPPDATA%\OpenAI\Codex\bin` is accepted; PATH and arbitrary configuration paths are not used.
- Guardian does not read Codex credentials, supply tokens, or persist raw protocol output or stderr. The short-lived Codex child may contact OpenAI using the existing Codex sign-in.
- Real startup validation without executing a task produced a `Codex app-server rate limits` snapshot. The probe child lived approximately 1.19 seconds, peaked at 18.74 MB private memory and 41.89 MB working set, exited normally, and left no extra Codex process.
- A subsequent 60-second app steady-state sample changed by +3.07 MB private memory, +3.22 MB working set, +1 handle, and 0 threads. Existing long-duration residency and watcher gates remain applicable because the new probe has no resident component.

## Data behavior

The live response on this machine contained the weekly window but no five-hour window. Weekly quota became live immediately. The five-hour track retained its independently timestamped fallback value and remained expired/gray; Guardian did not fabricate a current value.

## Candidate and local installation

- Folder: `D:\CodexGuardian\project\artifacts\local-candidate\1.0.0-rc.14\win-x64-20260720-015917`
- ZIP: `D:\CodexGuardian\project\artifacts\local-candidate\1.0.0-rc.14\CodexGuardian-local-test-1.0.0-rc.14-win-x64-20260720-015917.zip`
- SHA-256: `7ABEEEA01302A784F34DB4F755084D8432F72B63A5CDE7A873E2B5325758C182`
- Installed executable: `D:\CodexGuardian\runtime\app\CodexGuardian.App.exe`, product version `1.0.0-rc.14`; running and responding.
- Existing `FollowCodex=true` and its current-user Run entry were preserved; the updated watcher was restored after installation.

No repository, push, tag, or public release was created by this audit.
