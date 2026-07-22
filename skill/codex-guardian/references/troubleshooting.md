# Troubleshooting

## NO DATA

1. Confirm the Codex desktop app is signed in and running, then use Guardian's manual refresh once.
2. If active refresh remains unavailable, confirm `%USERPROFILE%\.codex\sessions` exists and run one normal Codex task.
3. Run `diagnose-guardian.ps1` again. The diagnostic is intentionally local-only and does not initiate an account request.
4. If session files exist but validated metadata does not, report a likely schema mismatch.

## STALE or EXPIRED

Open signed-in Codex and use Guardian's manual refresh first. If that path is unavailable, run one normal Codex task to generate a current event. Do not change the system clock or copy credentials.

## App does not start

1. Run the diagnostic script.
2. Confirm Windows is supported.
3. Prefer the self-contained win-x64 package.
4. Reinstall over the existing app directory; preserve data files.

## Widget disappeared

Use the Guardian tray menu and select `Show Guardian`. If the saved position is outside the current monitor layout, the app restores it to a visible screen on next launch.

## Follow-Codex startup does not work

1. Confirm `CodexGuardian.Watcher.exe` is beside `CodexGuardian.App.exe`.
2. Disable and re-enable the option in Guardian settings to refresh the current-user startup entry.
3. Confirm Codex is the packaged `OpenAI.Codex_*` desktop app; unrelated `ChatGPT.exe` processes are intentionally ignored.
4. Do not add administrator privileges, scheduled tasks, or broad process-name matching as a workaround.
