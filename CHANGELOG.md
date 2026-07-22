# Changelog

All notable changes will be documented in this file. The format follows Keep a Changelog, and releases use semantic versioning.

## [Unreleased]

### Added

- Local Codex session quota provider.
- Five-hour and weekly quota widget.
- Fresh, stale, expired, and unavailable states.
- Local sanitized history, predictor, advisor, diagnostic CLI, and system tray.
- Interactive scenario timeline, reserve strategies, task budgets, task summaries, and local weekly report.
- Explicit data retention, safe export, and two-step history clearing.
- Context-aware four-level notification delivery with actionable Active notices.
- Native Windows app notifications with view-timeline and silence-until-reset actions, plus a desktop fallback.
- Complete Simplified Chinese and English interface switching with persisted language preference.
- Explicit 30-minute, 2-hour, 5-hour, and 7-day trends plus local prediction replay error reporting.
- Minimal dark, glass, cyber, ember, aurora, and moss themes plus Per-Monitor V2 DPI support.
- Codex Skill workflows for environment detection, install, diagnose, repair, upgrade, and confirmation-first uninstall guidance.
- Optional `CODEX_GUARDIAN_HOME` for placing both the application and local data on another drive.
- Window-duration-based quota parsing with independent five-hour/weekly freshness and last-trusted local fallback.
- Always-visible dual quota tracks in the collapsed desktop capsule.
- Bottom-right docking with move-lock enabled by default and an explicit unlock control.
- A theme-independent low-presence display mode that can be combined with every palette.
- In-capsule refresh feedback that distinguishes a newer event, no change, and scan failure.
- A tray-only desktop-widget shell with state-aware show/hide commands and no taskbar button.
- Distinct local-activity flow and confirmed quota-change feedback, including percentage-point deltas; activity remains ambient without a persistent text badge.
- Transactional appearance preview in Settings: palette and ambient changes update both an inline capsule preview and the desktop widget, while Cancel restores the previous appearance.
- Sakura, frost, tidal, and solar palettes plus optional bounded petals, snow, fireflies, and starfall ambient effects.
- Optional follow-Codex startup using a trimmed local watcher with packaged-process allowlisting, one-launch-per-Codex-lifetime behavior, and immediate quota refresh.
- Startup and manual active quota refresh through the signed, running Codex app-server, with strict timeout/retry limits and local JSONL fallback.

### Changed

- The capsule now prioritizes remaining percentages and reset timing over low-frequency chrome actions.
- Partial quota metadata keeps available windows live while missing windows are labeled instead of failing the whole snapshot.
- Ambient state now coordinates border, status glyph, number color, and breathing; Passive advice expands an in-capsule forecast briefly without a system toast.
- Settings now use the capsule's surface, hairline, spacing, button, and control language.
- Position locking now freezes the user's current location; bottom-right docking is only the first-run default.
- User-hidden windows stay hidden during Passive advice; reduced-motion mode keeps transient signals static.
- Ambient effects use local vector particles only and stop when the window is hidden, system animations are disabled, reduced-motion mode is active, or WPF falls back to rendering tier 0.
- Windows sign-in startup and follow-Codex startup are mutually exclusive; follow mode is off by default and fully removes its current-user startup entry when disabled.
- The widget no longer waits for a new task event before attempting a current quota snapshot; successful startup probing runs once, while ordinary interval refreshes remain local.

### Security

- Provider is read-only, rejects unknown window shapes, and degrades safely window by window when metadata is partial.
- Guardian never reads Codex credentials or accepts an arbitrary executable path. Active refresh invokes only `account/rateLimits/read` through a running Codex executable under its user-local installation path; malformed responses fail closed.
