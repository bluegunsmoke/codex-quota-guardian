# Codex Guardian 1.0.0-rc.12 release audit

Audit date: 2026-07-15

## Verdict

The source, dependency, package, privacy, and residency gates pass. The candidate is ready for the maintainer's final local UI checklist. It has not been published, pushed, tagged, or committed.

## Automated evidence

- Release build: 0 warnings, 0 errors.
- Tests: 75 passed, 0 failed, 0 skipped.
- Coverage: 88.27% lines (700/793), 73.30% branches (401/547).
- NuGet audit: 0 known vulnerable direct or transitive packages.
- Formatting/analyzers: `dotnet format --verify-no-changes --severity warn` passes.
- Localization: Chinese and English catalogs and XAML references validate.
- Privacy: no application network client; diagnostic output contains no prompt, response, cookie, or token fields.
- Package hygiene: no PDB, settings, window-state, JSONL, authentication file, or user data.
- Installer safety: checksum mismatch and ZIP path traversal fixtures are rejected before extraction.
- CI supply chain: repository permissions are read-only and external Actions are pinned to full commit SHAs.

## Storage budgets

- Quota history: hard limit 16 MB; newest valid records win when the time or byte limit is reached.
- Notification decisions: hard limit 512 KB, then compact to the newest 500 entries.
- Settings and window state: fixed-size JSON documents.
- Release download staging: one fixed ZIP filename, overwritten on a later installer download; release ZIP budget 120 MB.
- Installed runtime: folder budget 230 MB; current candidate 204.71 MB.
- .NET bundle extraction: disabled; verified cache growth is 0 bytes.

## Candidate

- Folder: `D:\CodexGuardian\project\artifacts\local-candidate\1.0.0-rc.12\win-x64-20260715-000228`
- ZIP: `D:\CodexGuardian\project\artifacts\local-candidate\1.0.0-rc.12\CodexGuardian-local-test-1.0.0-rc.12-win-x64-20260715-000228.zip`
- Checksum: adjacent `.zip.sha256` file, required by the installer.
- ZIP SHA-256: `57C86B9141A80DBFBE6DF088790DD5CDCA80D73FD0451FDEDD4F8D3354111CAB`
- Files: 543
- Expanded size: 204.71 MB
- ZIP size: 80.50 MB
- Launcher size: 0.20 MB

The candidate is a folder-based self-contained application. It does not use .NET single-file extraction.

## 30-minute residency test

- Samples: 61 after a 30-second warmup; all responding.
- Working set: 192.4 MB to 196.2 MB, growth 3.8 MB.
- Private memory: 121.3 MB to 120.9 MB, growth -0.4 MB.
- Handles: 671 to 668, growth -3.
- Threads: 25 to 18, growth -7.
- Normalized average CPU: 0.026%.
- Guardian data growth: 15,808 bytes.
- Bundle-cache growth: 0 bytes.

The current machine still contains 4,453,420,887 bytes (4,247.11 MB) of legacy rc.11-and-earlier single-file extraction cache under `D:\CodexGuardian\runtime\bundle-cache`. It was not modified or deleted. Cleanup requires explicit maintainer authorization.

## Installed local candidate

- Path: `D:\CodexGuardian\runtime\app\CodexGuardian.App.exe`
- Installed size: 204.70 MB.
- Data size immediately after install: 142.79 KB.
- Installed `CodexGuardian.App.dll` matches the audited candidate SHA-256.
- The installed process launched from the D drive and responded normally.
- The real installer verified all 543 entries and 214,649,325 expanded bytes before writing.

## Security limits

The application itself has no network client and reads only normalized rate-limit metadata from local Codex session files. The optional release installer is the only networked component; it downloads from the configured GitHub repository, requires SHA-256 agreement, and rejects path traversal, symbolic links, more than 2,000 entries, or more than 350 MB expanded content.

The candidate is currently unsigned. Checksums detect corruption and mismatched assets but cannot prove publisher identity if the release account and checksum asset are compromised together. Code signing or verifiable build provenance remains recommended before describing the supply chain as fully authenticated.

## Remaining human gate

Open Settings from the Guardian tray icon and verify the selected text and popup items are readable for Language, Refresh interval, Theme, Strategy, and History retention. Then complete `docs/local-test-checklist.md`. This visual gate is intentionally not replaced by unit tests.
