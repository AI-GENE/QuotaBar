import Foundation

public struct ProviderState: Sendable {
    public private(set) var snapshot: QuotaSnapshot?
    public private(set) var error: QuotaError?
    public init() {}
    public mutating func succeed(_ snapshot: QuotaSnapshot) {
        self.snapshot = snapshot
        error = nil
    }
    public mutating func fail(_ error: QuotaError) {
        self.error = error
        if [.authentication, .denied, .credentialUnavailable, .probeTrust].contains(error) {
            snapshot = nil
        }
    }
    public func compact(at now: Date) -> String {
        guard let snapshot, let weekly = snapshot.weekly else { return "—" }
        if weekly.hasReset(at: now) { return "—" }
        return "\(weekly.remaining)%" + (error != nil || snapshot.isStale(at: now) ? "†" : "")
    }
}

public enum Provider: String, CaseIterable, Sendable { case claude, codex }
