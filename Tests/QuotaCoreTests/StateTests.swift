import Foundation
import Testing
@testable import QuotaCore

@Test func failedProviderDoesNotInventQuota() {
    let state = ProviderState()
    #expect(state.compact(at: .now) == "—")
}

@Test func refreshFailureMarksLastGoodValue() throws {
    let now = Date.now
    let snapshot = try QuotaSnapshot.claude(Data(#"{"seven_day":{"utilization":29}}"#.utf8), now: now)
    var state = ProviderState()
    state.succeed(snapshot)
    #expect(state.compact(at: now) == "71%")
    state.fail(.network)
    #expect(state.compact(at: now) == "71%†")
    #expect(state.error == .network)
}

@Test func authFailureClearsAccountValues() throws {
    var state = ProviderState()
    state.succeed(try .claude(Data(#"{"seven_day":{"utilization":29}}"#.utf8)))
    state.fail(.authentication)
    #expect(state.compact(at: .now) == "—")
}

@Test func successfulRefreshClearsError() throws {
    var state = ProviderState()
    state.fail(.network)
    state.succeed(try .claude(Data(#"{"seven_day":{"utilization":29}}"#.utf8)))
    #expect(state.error == nil)
}

@Test(arguments: [(401, QuotaError.authentication), (403, .denied), (429, .rateLimited), (500, .server)])
func httpStatusHasBoundedSafeError(status: Int, expected: QuotaError) {
    #expect(UsageClient.responseError(status) == expected)
}

@Test func successStatusHasNoError() {
    #expect(UsageClient.responseError(200) == nil)
}
