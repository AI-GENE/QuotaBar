import Foundation

private struct Credential {
    let token: String
    let accountID: String?
}

// Never follow redirects carrying an authorization header to another endpoint.
private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

public struct UsageClient: Sendable {
    public init() {}

    public static func responseError(_ status: Int) -> QuotaError? {
        switch status {
        case 200: nil
        case 401: .authentication
        case 403: .denied
        case 429: .rateLimited
        default: .server
        }
    }

    @concurrent
    public func fetch(_ provider: Provider) async throws -> QuotaSnapshot {
        if provider == .claude { return try await ClaudeCLI.fetch() }
        let credential = try Self.codexCredential()
        let endpoint = "https://chatgpt.com/backend-api/wham/usage"
        guard let url = URL(string: endpoint) else { throw QuotaError.invalidResponse }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("QuotaBar/1.0", forHTTPHeaderField: "User-Agent")
        if let id = credential.accountID {
            request.setValue(id, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 20
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        let session = URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw QuotaError.invalidResponse }
            if let error = Self.responseError(http.statusCode) { throw error }
            guard data.count < 1_000_000 else { throw QuotaError.invalidResponse }
            let result = try QuotaSnapshot.codex(data)
            guard result.session != nil || result.weekly != nil else { throw QuotaError.invalidResponse }
            return result
        } catch let error as QuotaError {
            throw error
        } catch is DecodingError {
            throw QuotaError.invalidResponse
        } catch {
            if error is URLError { throw QuotaError.network }
            throw QuotaError.invalidResponse
        }
    }

    private static func codexCredential() throws -> Credential {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let root = ProcessInfo.processInfo.environment["CODEX_HOME"].map { URL(fileURLWithPath: $0) }
            ?? home.appendingPathComponent(".codex")
        guard let data = try? Data(contentsOf: root.appendingPathComponent("auth.json")),
              let root = try? dictionary(data), let tokens = root["tokens"] as? [String: Any],
              let token = tokens["access_token"] as? String, !token.isEmpty else {
            throw QuotaError.credentialUnavailable
        }
        return Credential(token: token, accountID: tokens["account_id"] as? String)
    }
}
