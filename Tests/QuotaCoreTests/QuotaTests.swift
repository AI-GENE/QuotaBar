import Foundation
import Testing
@testable import QuotaCore

private func data(_ text: String) -> Data { Data(text.utf8) }

@Test func claudeConvertsUsedIntoRemaining() throws {
    let q = try QuotaSnapshot.claude(data(#"{"five_hour":{"utilization":13},"seven_day":{"utilization":29}}"#))
    #expect(q.session?.remaining == 87)
    #expect(q.weekly?.remaining == 71)
}

@Test func parsesFractionalISODate() throws {
    let q = try QuotaSnapshot.claude(data(#"{"seven_day":{"utilization":29,"resets_at":"2025-01-15T09:00:00.123456+00:00"}}"#))
    #expect(q.weekly?.resetsAt != nil)
}

@Test func codexPrimaryCanBeWeekly() throws {
    let q = try QuotaSnapshot.codex(data(#"{"rate_limit":{"primary_window":{"used_percent":17,"limit_window_seconds":604800,"reset_at":1736899200},"secondary_window":null}}"#))
    #expect(q.weekly?.remaining == 83)
    #expect(q.session == nil)
    #expect(q.weekly?.resetsAt == Date(timeIntervalSince1970: 1736899200))
}

@Test func codexMapsTwoWindowsByDuration() throws {
    let q = try QuotaSnapshot.codex(data(#"{"rate_limit":{"primary_window":{"used_percent":10,"limit_window_seconds":18000},"secondary_window":{"used_percent":40,"limit_window_seconds":604800}}}"#))
    #expect(q.session?.remaining == 90)
    #expect(q.weekly?.remaining == 60)
}

@Test(arguments: ["null", "{}", #"{"utilization":null}"#, #"{"utilization":"29"}"#, #"{"utilization":true}"#, #"{"utilization":-1}"#, #"{"utilization":101}"#])
func claudeInvalidWindowStaysUnavailable(window: String) throws {
    let q = try QuotaSnapshot.claude(data("{\"seven_day\":\(window)}"))
    #expect(q.weekly == nil)
}

@Test func missingClaudeSessionIsNotSubstitutedWithWeekly() throws {
    let q = try QuotaSnapshot.claude(data(#"{"five_hour":null,"seven_day":{"utilization":100}}"#))
    #expect(q.session == nil)
    #expect(q.weekly?.remaining == 0)
}

@Test func zeroUsageReallyMeansOneHundredRemaining() throws {
    let q = try QuotaSnapshot.claude(data(#"{"seven_day":{"utilization":0}}"#))
    #expect(q.weekly?.remaining == 100)
}

@Test func fractionDoesNotOverstateRemaining() throws {
    let q = try QuotaSnapshot.claude(data(#"{"seven_day":{"utilization":29.2}}"#))
    #expect(q.weekly?.remaining == 70)
}

@Test func missingCodexPercentIsNotZeroUsage() throws {
    let q = try QuotaSnapshot.codex(data(#"{"rate_limit":{"primary_window":{"limit_window_seconds":604800}}}"#))
    #expect(q.weekly == nil)
}

@Test func unknownCodexWindowIsNotGuessed() throws {
    let q = try QuotaSnapshot.codex(data(#"{"rate_limit":{"primary_window":{"used_percent":20,"limit_window_seconds":3600}}}"#))
    #expect(q.weekly == nil)
    #expect(q.session == nil)
}

@Test func rejectsMalformedResponse() {
    #expect(throws: (any Error).self) { try QuotaSnapshot.claude(data("not-json")) }
    #expect(throws: (any Error).self) { try QuotaSnapshot.codex(data("[]")) }
}

@Test func marksOldMeasurementStale() throws {
    let now = Date(timeIntervalSince1970: 1800000000)
    let q = try QuotaSnapshot.claude(data("{}"), now: now)
    #expect(!q.isStale(at: now.addingTimeInterval(300)))
    #expect(q.isStale(at: now.addingTimeInterval(601)))
}

@Test func resetWindowIsNotShownAsCurrent() throws {
    let now = Date(timeIntervalSince1970: 1800000000)
    let q = try QuotaSnapshot.claude(data(#"{"seven_day":{"utilization":29,"resets_at":"2025-01-15T09:00:00Z"}}"#), now: now)
    #expect(q.isStale(at: now))
}
