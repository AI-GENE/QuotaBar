import Foundation
import Testing
@testable import QuotaCore

@Test func officialCLIUsedPercentAndResetAreParsed() throws {
    let text = """
    Current session
    20% 20% used
    Resets 5:40pm (Etc/UTC)
    Current week (all models)
    35% 35% used
    Resets Jan 15 at 9am (Etc/UTC)
    Current week (Fable)
    0% 0% used
    """
    let now = Date(timeIntervalSince1970: 1736899200) // Synthetic: 2025-01-15 00:00 UTC.
    let q = try ClaudeCLI.parse(text, now: now)
    #expect(q.session?.remaining == 80)
    #expect(q.weekly?.remaining == 65)
    #expect(q.session?.resetsAt != nil)
    #expect(q.weekly?.resetsAt != nil)
    #expect(q.weekly?.resetsAt?.ISO8601Format() == "2025-01-15T09:00:00Z")
    #expect(q.session?.resetsAt?.ISO8601Format() == "2025-01-15T17:40:00Z")
}

@Test func currentWeekNeverUsesScopedModelPercent() throws {
    let q = try ClaudeCLI.parse("Current week (Fable)\n10% used")
    #expect(q.weekly == nil)
}

@Test func supportsLeftLabel() throws {
    let q = try ClaudeCLI.parse("Current session\n86% left\nCurrent week (all models)\n71% left")
    #expect(q.weekly?.remaining == 71)
    #expect(q.session?.remaining == 86)
}

@Test func rendersCursorRewritesBeforeParsing() throws {
    let terminal = "Current session\r\n12% used\r\nCurrent week (all models)\r\n28% used\u{1b}[2A\r\u{1b}[2KCurrent week (all models)\r\n\u{1b}[2K29% used"
    let q = try ClaudeCLI.parse(ClaudeCLI.screen(terminal))
    #expect(q.weekly?.remaining == 71)
}

@Test func partialCLIResponseDoesNotFabricateValue() throws {
    let q = try ClaudeCLI.parse("Current session\nLoading…\nCurrent week (all models)\nLoading…")
    #expect(q.weekly == nil)
    #expect(q.session == nil)
}

@Test func extremeANSICursorParametersDoNotOverflow() {
    let down = ClaudeCLI.screen("\n\u{1b}[\(Int.max)Bsafe")
    #expect(down.contains("safe"))
    let position = ClaudeCLI.screen("\u{1b}[1;\(Int.min)Hsafe")
    #expect(position.contains("safe"))
}

@Test func rateLimitDetectionIgnoresIncidentalDigits() {
    #expect(!ClaudeCLI.isRateLimit("Claude Code v1.2.429\nWelcome user429"))
    #expect(ClaudeCLI.isRateLimit("Error: HTTP 429 Too Many Requests"))
    #expect(ClaudeCLI.isRateLimit("Rate limit exceeded (429)"))
}

@Test func probeHasDeterministicSafeEnvironmentAndNodePath() {
    let inherited = ["HOME": "/synthetic/home", "PATH": "/usr/bin:/bin", "NODE_OPTIONS": "synthetic-test",
                     "ANTHROPIC_API_KEY": "synthetic-not-a-token", "ANTHROPIC_BASE_URL": "https://invalid.example",
                     "HTTPS_PROXY": "http://proxy.example", "CLAUDE_CONFIG_DIR": "/synthetic/config"]
    let environment = ClaudeCLI.probeEnvironment(inherited, executable: "/opt/homebrew/bin/claude")
    #expect(environment["PATH"]?.hasPrefix("/opt/homebrew/bin:") == true)
    #expect(environment["PATH"]?.contains("/usr/local/bin") == true)
    #expect(environment["NODE_OPTIONS"] == nil)
    #expect(environment["ANTHROPIC_API_KEY"] == nil)
    #expect(environment["ANTHROPIC_BASE_URL"] == nil)
    #expect(environment["HTTPS_PROXY"] == inherited["HTTPS_PROXY"])
    #expect(environment["CLAUDE_CONFIG_DIR"] == inherited["CLAUDE_CONFIG_DIR"])
    #expect(environment["HOME"] == inherited["HOME"])
}
