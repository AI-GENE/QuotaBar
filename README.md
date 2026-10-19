# QuotaBar

A small, native macOS menu-bar utility for Claude Code and Codex usage limits.

Two monochrome service marks. Two remaining percentages. No dashboard to keep open.

## What it shows

- Claude on the left, Codex on the right: **weekly remaining usage**, not dollars or API credits.
- Click for five-hour windows, reset times, errors, and manual refresh.
- Refreshes approximately every five minutes while awake, and on wake.
- Missing data stays `—`. Stale data is marked `†`; an expired window is not presented as current.
- Optional launch at login, disabled by default. No Electron or runtime package dependencies.

The initial interface is in Chinese. Service logos adapt to the macOS menu-bar appearance.

## Requirements and first run

The deployment target is macOS 14+. The initial downloadable build is Apple Silicon;
it is tested on macOS 26.5, not on every supported macOS release. Building requires Swift 6.2+ and Xcode command-line tools.

1. Sign in to the official Codex client. QuotaBar currently supports its file-based OAuth credentials at `$CODEX_HOME/auth.json` or `~/.codex/auth.json`. Keychain-only storage and API-key-only accounts are not supported.
2. Install the official Claude Code CLI and sign in with your Claude subscription. QuotaBar looks for `claude` in `~/.local/bin`, `/opt/homebrew/bin`, or `/usr/local/bin`.
3. Initialize the dedicated Claude usage-query directory once, yourself:

   ```sh
   mkdir -p "$HOME/Library/Application Support/QuotaBar/Probe"
   cd "$HOME/Library/Application Support/QuotaBar/Probe"
   claude --safe-mode --no-chrome --strict-mcp-config --mcp-config '{"mcpServers":{}}' --tools '' --settings '{"remoteControlAtStartup":false}' --ax-screen-reader /usage
   ```

   If Claude asks about workspace trust, check that it names **only this Probe directory** before deciding whether to trust it. Complete any official login/setup prompts yourself, then quit Claude with Ctrl-C. QuotaBar does not automatically accept trust or security prompts.
4. Open QuotaBar. It lives in the menu bar, not the Dock. On a crowded or notched menu bar, other items may need to be hidden first.

## Download or build

Download builds, when available, are attached to [GitHub Releases](https://github.com/AI-GENE/QuotaBar/releases).
The first release is an **ad-hoc-signed developer preview, not Apple-notarized**. Expect macOS Gatekeeper to block a quarantined download by default. An ad-hoc signature does not verify the publisher's identity; release assets include SHA-256 checksums for integrity, not proof of trust. Do not disable Gatekeeper; build from source or wait for a notarized release if your policy requires one.

```sh
git clone https://github.com/AI-GENE/QuotaBar.git
cd QuotaBar
./build.sh
```

This runs the offline tests, builds the application, bundles its vector resources, and applies a local ad-hoc signature. The result is `dist/QuotaBar.app`. Copy that application to your Applications folder if desired. No signing credentials are included.
Custom `CODEX_HOME` is read from the launch environment, not your shell profile when launched from Finder. Ad-hoc rebuilds may require re-enabling launch at login.

## Privacy and security

QuotaBar has no developer-operated server, analytics, or telemetry. It does make authenticated provider requests:

- **Codex:** reads the existing OAuth access token and account ID into memory, then sends them only to the fixed HTTPS usage endpoint on `chatgpt.com`. Redirects, persistent cookies, and HTTP caches are disabled. QuotaBar does not refresh or rewrite credentials.
- **Claude:** invokes the official local CLI's built-in `/usage` command in the dedicated Probe directory, with tools, Chrome integration, customizations, MCP servers, and startup remote control disabled. QuotaBar does not read Claude's Keychain item or receive the token. The CLI authenticates and contacts its own services; its own session metadata may be written under its normal settings.
- Captured usage-query output is held in memory, bounded, and never written by QuotaBar. Debug `--check` output contains usage values and fixed error messages, not tokens or account identifiers. Usage values and reset times are still personal data; redact them before sharing diagnostics.
- Login, credential rotation, Keychain prompts, and security decisions remain with the official clients and the user. Never paste tokens into QuotaBar issues.

These integrations rely on provider-specific behavior, not a guaranteed public usage API. CLI output, endpoints, access policies, or account availability can change. QuotaBar may then show unavailable data until updated. It is not affiliated with or endorsed by Anthropic or OpenAI.

## Development

```sh
swift test
swift run QuotaBar
```

Tests use synthetic fixtures and require no credentials or provider requests. Running the application or `--check` **does** query your accounts. Never use live credentials in CI.

## License

Application code: MIT. Service marks retain their owners' rights. See [brand notices](Sources/QuotaCore/Resources/BrandNotices.txt) for the Simple Icons and LobeHub asset sources and licensing.
