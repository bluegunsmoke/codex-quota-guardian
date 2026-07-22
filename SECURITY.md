# Security policy

Until the first stable release, security fixes are applied to the default branch.

Do not open a public issue for a vulnerability that could expose local Codex data or credentials. Use GitHub private vulnerability reporting when it is enabled for the repository.

Never attach `auth.json`, session JSONL files, prompts, source code, cookies, or access tokens.

## Security boundaries

- Guardian must not read `%USERPROFILE%\.codex\auth.json`.
- Providers must not transmit local session data.
- Active quota refresh may invoke only the fixed read-only `account/rateLimits/read` method through a currently running Codex executable normalized beneath `%LOCALAPPDATA%\OpenAI\Codex\bin`; arbitrary paths and methods are rejected.
- Active refresh has an eight-second timeout, does not persist raw protocol output or stderr, and never reads or supplies credentials.
- Logs and history may contain quota numbers and timestamps only.
- Invalid or unknown provider data must fail closed.
- Release installation requires a matching SHA-256 checksum before extraction.
- The installer rejects ZIP path traversal, symbolic links, more than 2,000 files, and expanded content above 350 MB.
- Runtime history and notification logs have independent hard byte ceilings.
- Follow-Codex startup is opt-in, user-scoped, and restricted to packaged `OpenAI.Codex_*` executable paths; the watcher itself has no network client, logging, elevation, or arbitrary command input.

## Release integrity

GitHub Actions use read-only repository permissions and third-party actions pinned to full commit SHAs. Automated dependency updates monitor both NuGet and GitHub Actions. Release ZIPs must be published with the generated `.sha256` asset.

The first release candidate is not code-signed. A SHA-256 checksum protects against accidental corruption and mismatched assets, but it does not replace publisher identity verification if the release account itself is compromised. Code signing or a verifiable provenance workflow remains a post-candidate hardening item.
