# Codex Guardian 1.0.0-rc.13 release audit

Audit date: 2026-07-15

## Verdict

The source, dependency, package, privacy, installer, and watcher-residency gates pass. The candidate is installed locally for the maintainer's final UI and behavior check. It has not been published, pushed, tagged, or committed.

## Automated evidence

- Release build: 0 warnings, 0 errors.
- Tests: 83 passed, 0 failed, 0 skipped.
- Coverage: 88.43% lines (711/804), 73.69% branches (409/555).
- NuGet audit: 0 known vulnerable direct or transitive packages.
- Formatting/analyzers: `dotnet format --verify-no-changes` passes.
- Localization: 221 Chinese/English resource keys, 194 references, and 0 hard-coded user-facing XAML strings.
- Privacy: 0 application network API references; diagnostic output contains no prompt, response, cookie, or token fields.
- Package hygiene: no PDB, settings, window-state, JSONL, authentication file, or user data.
- Installer safety: checksum mismatch and ZIP path traversal fixtures are rejected before extraction.
- Running-watcher upgrade: the installer signaled a watcher from the exact install path, waited for a clean exit, then verified and replaced 544 package files without force-killing it.

## Follow-Codex behavior and safety

- Disabled by default and mutually exclusive with starting Guardian immediately at Windows sign-in.
- Uses one current-user `HKCU\\...\\Run` entry; no administrator permission, service, scheduled task, driver, or shell command is required.
- Accepts only `ChatGPT.exe` paths under a packaged `WindowsApps\\OpenAI.Codex_*\\app` location.
- Starts Guardian once per observed Codex lifecycle. Manually exiting Guardian does not create a relaunch loop; the gate re-arms after Codex exits.
- Enabling or disabling is transactional. An unavailable watcher, unwritable Run key, missing process path, or overlong Run command leaves the saved setting unchanged and attempts to restore the prior registration.
- The watcher has no network client, log, cache, prompt inspection, window-text inspection, or command-line inspection.

## Watcher 30-minute residency test

- Final executable: the watcher packaged in the `20260715-105122` candidate; source and binary match the final audited implementation.
- Samples: 121 over 30.05 minutes.
- Maximum private memory: 6.99 MB (release limit: 20 MB).
- Private-memory delta including startup: +2,932 KB.
- Working-set delta including startup: +4,744 KB.
- Handle delta including startup: +16; the steady-state sample remained at 183 handles.
- Thread delta: -4.
- Normalized average CPU: rounded to 0.00000% by the audit script (release limit: 0.05%).
- TCP endpoints: 0; UDP endpoints: 0 during live inspection.
- Bundle-cache growth: 0 bytes.

The first implementation was not accepted after private memory kept climbing to about 10 MB by minute 11. The final implementation validates the packaged Codex path once, then checks the trusted PID and process start time until that process exits. The complete 30-minute test above was restarted from the final optimized binary.

## Candidate and installed copy

- Folder: `D:\CodexGuardian\project\artifacts\local-candidate\1.0.0-rc.13\win-x64-20260715-105424`
- ZIP: `D:\CodexGuardian\project\artifacts\local-candidate\1.0.0-rc.13\CodexGuardian-local-test-1.0.0-rc.13-win-x64-20260715-105424.zip`
- ZIP SHA-256: `5A9DB682138766F697EAC93E04210068803D22E5B8B3D06478582F9DD55B0B05`
- Files: 544.
- Expanded size: 216.28 MB.
- ZIP size: 85.65 MB.
- Launcher size: 0.20 MB.
- Watcher size: 11.56 MB.
- Installed executable: `D:\CodexGuardian\runtime\app\CodexGuardian.App.exe`, version `1.0.0-rc.13`; launched and responding.
- The local runtime contains one intentional 97-byte `preserve-marker.txt` test marker in addition to the 544 package files; it is not part of the release ZIP.

## Storage boundaries

- Quota history: hard limit 16 MB.
- Notification decisions: hard limit 512 KB, compacted to the newest 500 entries.
- Settings and window state: fixed-size JSON documents.
- Release download staging: one fixed ZIP filename; later downloads overwrite the bounded slot.
- Installed folder budget: 230 MB; current candidate 216.28 MB.
- Release ZIP budget: 120 MB; current candidate 85.65 MB.
- Current runtime data: 272,203 bytes across four files.
- Current legacy single-file bundle cache: 4,453,420,887 bytes; the folder-based app and watcher added 0 bytes. It remains untouched pending explicit deletion permission.
- Source restore cache: 982,661,397 bytes in the ignored D-drive `work/.nuget/packages` directory. It affects maintainers only, not ZIP users or the installed app.
- A failed Native AOT feasibility attempt left 415,011 bytes under the system NuGet cache. It was not deleted without permission and did not grow during final restore/build/audit because all later packages were redirected to D.

## Remaining human gate

Open Settings from the tray icon and verify the new “跟随 Codex 启动 Guardian” row, its explanatory text, and mutual exclusion with “登录 Windows 时启动 Guardian”. Then enable it once, close Guardian, close/reopen Codex, and confirm Guardian starts and refreshes quota. Disable it afterward if it should not remain active. Complete the rest of `docs/local-test-checklist.md` before publication.
