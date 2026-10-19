import Foundation
import Darwin

public enum ClaudeCLI {
    public static func parse(_ text: String, now: Date = .now) throws -> QuotaSnapshot {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        func window(_ headings: [String]) -> UsageWindow? {
            guard let start = lines.lastIndex(where: { headings.contains($0.lowercased()) }) else { return nil }
            let section = lines.dropFirst(start + 1).prefix(while: { !$0.lowercased().hasPrefix("current ") })
            let regex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)%\s*(used|left|remaining)"#)
            for line in section {
                let range = NSRange(line.startIndex..., in: line)
                guard let match = regex?.firstMatch(in: line, range: range),
                      let numberRange = Range(match.range(at: 1), in: line),
                      let kindRange = Range(match.range(at: 2), in: line),
                      let value = Double(line[numberRange]), (0...100).contains(value) else { continue }
                let used = line[kindRange] == "used" ? value : 100 - value
                let reset = section.first { $0.hasPrefix("Resets ") }.flatMap { resetDate($0, now: now) }
                return UsageWindow(used: used, resetsAt: reset)
            }
            return nil
        }
        return QuotaSnapshot(session: window(["current session"]),
            weekly: window(["current week (all models)", "current week"]), fetchedAt: now)
    }

    private static func resetDate(_ text: String, now: Date) -> Date? {
        var input = String(text.dropFirst("Resets ".count))
        var zone = TimeZone.current
        if let open = input.lastIndex(of: "("), input.hasSuffix(")") {
            zone = TimeZone(identifier: String(input[input.index(after: open)..<input.index(before: input.endIndex)])) ?? zone
            input = String(input[..<open]).trimmingCharacters(in: .whitespaces)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.defaultDate = now
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        for format in ["h:mma", "ha", "MMM d 'at' h:mma", "MMM d 'at' ha"] {
            formatter.dateFormat = format
            if var result = formatter.date(from: input) {
                var parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: result)
                if !format.contains("mm") { parts.minute = 0 }
                parts.second = 0
                parts.nanosecond = 0
                result = calendar.date(from: parts) ?? result
                if result < now {
                    result = calendar.date(byAdding: input.contains(" at ") ? .year : .day, value: 1, to: result) ?? result
                }
                return result
            }
        }
        return nil
    }

    // The screen-reader UI still rewrites lines with ANSI cursor control. Rebuild
    // the current screen rather than parsing an obsolete percentage from the transcript.
    public static func screen(_ text: String) -> String {
        let chars = Array(text.unicodeScalars)
        var rows = [[Unicode.Scalar]()]
        var row = 0, column = 0, savedRow = 0, savedColumn = 0, i = 0
        func ensure() { while rows.count <= row { rows.append([]) } }
        while i < chars.count {
            let c = chars[i]; i += 1
            if c.value == 27 {
                guard i < chars.count else { break }
                let next = chars[i]; i += 1
                if next == "[" {
                    var parameters = ""
                    while i < chars.count && !(64...126).contains(chars[i].value) {
                        parameters.unicodeScalars.append(chars[i]); i += 1
                    }
                    guard i < chars.count else { break }
                    let code = chars[i]; i += 1
                    let numbers = parameters.split(separator: ";", omittingEmptySubsequences: false)
                        .map { min(1000, max(0, Int($0) ?? 0)) }
                    let n = max(1, numbers.first ?? 1)
                    switch code {
                    case "A": row = max(0, row - n)
                    case "B": row = min(499, row + n)
                    case "C": column = min(399, column + n)
                    case "D": column = max(0, column - n)
                    case "G": column = min(399, n - 1)
                    case "H", "f": row = min(499, n - 1); column = min(399, max(0, (numbers.dropFirst().first ?? 1) - 1))
                    case "K":
                        ensure()
                        if numbers.first == 2 { rows[row] = [] }
                        else if column < rows[row].count { rows[row].removeSubrange(column...) }
                    case "J":
                        if numbers.first == 2 { rows = [[]]; row = 0; column = 0 }
                    default: break
                    }
                } else if next == "]" {
                    while i < chars.count {
                        if chars[i].value == 7 { i += 1; break }
                        if chars[i].value == 27 && i + 1 < chars.count && chars[i + 1] == "\\" { i += 2; break }
                        i += 1
                    }
                } else if next == "7" { savedRow = row; savedColumn = column }
                else if next == "8" { row = savedRow; column = savedColumn }
                else if next == "(" || next == ")" { i = min(chars.count, i + 1) }
            } else if c.value == 13 { column = 0 }
            else if c.value == 10 { row = min(499, row + 1); ensure() }
            else if c.value >= 32 && c.value != 127 {
                ensure()
                while rows[row].count <= column { rows[row].append(" ") }
                rows[row][column] = c
                column = min(399, column + 1)
            }
        }
        return rows.map { String(String.UnicodeScalarView($0)) }.joined(separator: "\n")
    }

    @concurrent
    static func fetch() async throws -> QuotaSnapshot {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [home.appendingPathComponent(".local/bin/claude").path, "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
        guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw QuotaError.credentialUnavailable
        }
        let cwd = home.appendingPathComponent("Library/Application Support/QuotaBar/Probe")
        try FileManager.default.createDirectory(at: cwd, withIntermediateDirectories: true)
        var master: Int32 = 0, slave: Int32 = 0
        var size = winsize(ws_row: 80, ws_col: 140, ws_xpixel: 0, ws_ypixel: 0)
        guard openpty(&master, &slave, nil, nil, &size) == 0 else { throw QuotaError.network }
        let masterHandle = FileHandle(fileDescriptor: master, closeOnDealloc: true)
        let slaveHandle = FileHandle(fileDescriptor: slave, closeOnDealloc: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["--safe-mode", "--no-chrome", "--strict-mcp-config", "--mcp-config", "{\"mcpServers\":{}}",
            "--tools", "", "--settings", "{\"remoteControlAtStartup\":false}", "--ax-screen-reader", "/usage"]
        process.currentDirectoryURL = cwd
        process.environment = probeEnvironment(ProcessInfo.processInfo.environment, executable: executable)
        process.standardInput = slaveHandle
        process.standardOutput = slaveHandle
        process.standardError = slaveHandle
        try process.run()
        try? slaveHandle.close()
        defer {
            if process.isRunning { process.terminate() }
            // Kill only our dedicated no-tools probe if it ignores TERM.
            for _ in 0..<10 where process.isRunning { usleep(20_000) }
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            try? masterHandle.close()
        }
        _ = fcntl(master, F_SETFL, O_NONBLOCK)
        let deadline = Date.now.addingTimeInterval(25)
        var capture = Data()
        var lastChange = Date.now
        var buffer = [UInt8](repeating: 0, count: 8192)
        while Date.now < deadline {
            try Task.checkCancellation()
            var descriptor = pollfd(fd: master, events: Int16(POLLIN), revents: 0)
            _ = poll(&descriptor, 1, 100)
            let count = read(master, &buffer, buffer.count)
            if count > 0 {
                capture.append(contentsOf: buffer.prefix(count))
                lastChange = .now
                if capture.count > 1_000_000 { throw QuotaError.invalidResponse }
            }
            let text = screen(String(decoding: capture, as: UTF8.self))
            if text.contains("Enter y/n:") { throw QuotaError.probeTrust }
            if text.contains("Please run /login") || text.contains("Not logged in") { throw QuotaError.authentication }
            if isRateLimit(text) { throw QuotaError.rateLimited }
            if Date.now.timeIntervalSince(lastChange) > 1.5 && !text.contains("Refreshing") {
                let snapshot = try parse(text)
                if snapshot.weekly != nil { return snapshot }
            }
            if !process.isRunning { break }
        }
        throw QuotaError.network
    }

    static func isRateLimit(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("too many requests") || lower.contains("rate limit exceeded") { return true }
        return lower.range(of: #"\b(?:http(?:/\S+)?\s+|status(?:\s+code)?[\s:]+|error[\s:]+)429\b"#,
                           options: .regularExpression) != nil
    }

    static func probeEnvironment(_ inherited: [String: String], executable: String) -> [String: String] {
        let allowed = Set(["HOME", "USER", "LOGNAME", "TMPDIR", "CLAUDE_CONFIG_DIR",
            "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY", "http_proxy", "https_proxy", "all_proxy", "no_proxy",
            "SSL_CERT_FILE", "SSL_CERT_DIR", "NODE_EXTRA_CA_CERTS",
            "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC", "DO_NOT_TRACK", "DISABLE_TELEMETRY",
            "DISABLE_ERROR_REPORTING", "DISABLE_AUTOUPDATER", "DISABLE_FEEDBACK_COMMAND"])
        var environment = inherited.filter { allowed.contains($0.key) }
        // Finder/login-item launches do not source shell profiles. npm's CLI
        // wrapper needs node alongside the selected executable or in Homebrew.
        let directory = URL(fileURLWithPath: executable).deletingLastPathComponent().path
        environment["PATH"] = [directory, "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }.joined(separator: ":")
        environment["TERM"] = "xterm-256color"
        environment["LANG"] = "en_US.UTF-8"
        environment["LC_ALL"] = "en_US.UTF-8"
        // Avoid forcing the broad traffic switch: CLI initialization can then
        // fail to load usage. Keep granular privacy defaults and user overrides.
        for key in ["DISABLE_TELEMETRY", "DISABLE_ERROR_REPORTING", "DISABLE_AUTOUPDATER", "DISABLE_FEEDBACK_COMMAND"] {
            if environment[key] == nil { environment[key] = "1" }
        }
        return environment
    }
}
