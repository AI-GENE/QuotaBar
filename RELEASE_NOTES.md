# QuotaBar 1.0.0 Preview 1

Native macOS menu-bar monitor for Claude Code and Codex weekly remaining usage.
No compilation required for the downloadable Apple Silicon app.

## Downloads

- `QuotaBar.dmg`: drag QuotaBar into Applications.
- `QuotaBar.zip`: alternative application bundle.
- `SHA256SUMS.txt`: SHA-256 checksums for both packages.

## Before installing

**Developer preview — ad-hoc signed, NOT Developer ID signed or Apple-notarized.**
macOS Gatekeeper normally blocks quarantined downloads of this type. Do not disable Gatekeeper.
Checksums establish integrity, not publisher identity. Wait for a notarized build if your security policy requires one.

Apple Silicon only. The deployment target is macOS 14; testing was on macOS 26.5.
Existing official Codex OAuth login and an initialized Claude Code subscription login are required;
see [first-run instructions](https://github.com/AI-GENE/QuotaBar#requirements-and-first-run).
The initial interface is in Chinese.

## Included

- Compact monochrome Claude-left / Codex-right quota badge.
- Five-hour and weekly details, reset times, refresh and optional launch at login.
- Original navy app icon with a transparent outer background and Retina icon sizes.
- Short download filenames and a branded mounted-disk icon. A local Finder custom icon is also applied to the DMG file; ordinary web downloads may discard that file metadata.
- English project homepage with a separate [简体中文 guide](https://github.com/AI-GENE/QuotaBar/blob/main/README.zh-CN.md).
- A Claude Code 2.1.303 usage-loading compatibility correction: separate privacy controls replace the previously forced broad traffic restriction, while preserving explicit user overrides.
- 31 offline tests, release build, bundle signature and packaged-file checks.

## Known limitations

Claude Code's built-in `/usage` can still return `Failed to load usage data` for other reasons.
The reproduced query-mode compatibility issue was corrected; provider availability is not guaranteed.
QuotaBar currently depends on that CLI source for Claude, so other users can also be affected.
Stale values are marked `†`; missing values show `—`. They must not be treated as fresh quota readings.
The current generic timeout message does not identify the underlying HTTP error.
Codex five-hour data may be absent even when weekly data is available.

No login credentials, account identifiers, real quota screenshots or internal documents are included.
Service marks belong to their respective owners; QuotaBar is an independent utility.
