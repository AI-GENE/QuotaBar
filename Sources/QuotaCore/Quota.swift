import Foundation
import CoreFoundation

public struct UsageWindow: Sendable {
    public let used: Double
    public let resetsAt: Date?
    public var remaining: Int { Int(floor(100 - used)) }
    public func hasReset(at now: Date) -> Bool { resetsAt.map { $0 <= now } ?? false }
}

public struct QuotaSnapshot: Sendable {
    public let session: UsageWindow?
    public let weekly: UsageWindow?
    public let fetchedAt: Date
    public func isStale(at now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) > 600 || (weekly?.hasReset(at: now) ?? false)
    }
    public static func claude(_ data: Data, now: Date = .now) throws -> Self {
        let root = try dictionary(data)
        func window(_ key: String) -> UsageWindow? {
            guard let object = root[key] as? [String: Any],
                  let used = percent(object["utilization"]) else { return nil }
            return UsageWindow(used: used, resetsAt: isoDate(object["resets_at"] as? String))
        }
        return Self(session: window("five_hour"), weekly: window("seven_day"), fetchedAt: now)
    }
    public static func codex(_ data: Data, now: Date = .now) throws -> Self {
        let root = try dictionary(data)
        let limits = root["rate_limit"] as? [String: Any] ?? [:]
        var session: UsageWindow?
        var weekly: UsageWindow?
        for key in ["primary_window", "secondary_window"] {
            guard let object = limits[key] as? [String: Any],
                  let used = percent(object["used_percent"]),
                  let duration = number(object["limit_window_seconds"]) else { continue }
            let reset = number(object["reset_at"]).map { Date(timeIntervalSince1970: $0) }
            let window = UsageWindow(used: used, resetsAt: reset)
            if duration == 18_000 { session = window }
            if duration == 604_800 { weekly = window }
        }
        return Self(session: session, weekly: weekly, fetchedAt: now)
    }
}

func dictionary(_ data: Data) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw QuotaError.invalidResponse
    }
    return object
}

private func number(_ value: Any?) -> Double? {
    guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
          value.doubleValue.isFinite else { return nil }
    return value.doubleValue
}

private func percent(_ value: Any?) -> Double? {
    guard let value = number(value), (0...100).contains(value) else { return nil }
    return value
}

private func isoDate(_ text: String?) -> Date? {
    guard let text else { return nil }
    let parser = ISO8601DateFormatter()
    parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = parser.date(from: text) { return date }
    parser.formatOptions = [.withInternetDateTime]
    return parser.date(from: text)
}

public enum QuotaError: Error, Sendable, Equatable {
    case credentialUnavailable
    case authentication
    case denied
    case rateLimited
    case server
    case network
    case invalidResponse
    case probeTrust

    public var message: String {
        switch self {
        case .credentialUnavailable: "未找到登录凭据，请先登录官方客户端"
        case .authentication: "登录已失效，请在官方客户端重新登录"
        case .denied: "服务拒绝读取额度，请检查账户权限"
        case .rateLimited: "查询过于频繁，稍后自动重试"
        case .server: "额度服务暂不可用"
        case .network: "网络请求失败或超时"
        case .invalidResponse: "服务未返回可识别的额度数据"
        case .probeTrust: "请先在 QuotaBar 的专用查询目录完成 Claude Code 初始化"
        }
    }
}
