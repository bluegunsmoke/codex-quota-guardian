# Contributing

Thank you for helping improve Codex Guardian.

## Before opening a pull request

1. Open an issue for substantial behavior or provider-contract changes.
2. Keep quota providers read-only and narrowly scoped.
3. Never add authentication tokens, cookies, session files, prompts, or user content to fixtures.
4. Add regression tests for parser, prediction, and notification-policy changes.
5. Run the complete Release build and test commands from the README.

## Pull-request checklist

- [ ] The change has a focused purpose.
- [ ] Tests cover failure and stale-data behavior.
- [ ] No personal session data is committed.
- [ ] UI changes were checked at 100% and 150% display scaling.
- [ ] User-facing behavior or compatibility notes are documented.

## Commit style

Use short imperative subjects such as `Handle null rate-limit windows` or `Add stale-data badge`.
