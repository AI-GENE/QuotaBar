import AppKit
import ServiceManagement
import QuotaCore

@main
struct QuotaBarMain {
    static var delegate: AppDelegate?

    static func main() async {
        if CommandLine.arguments.contains("--check") {
            let client = UsageClient()
            for provider in Provider.allCases {
                do {
                    let q = try await client.fetch(provider)
                    var output: [String: Any] = ["provider": provider.rawValue, "ok": true]
                    output["weeklyRemaining"] = q.weekly?.remaining
                    output["fiveHourRemaining"] = q.session?.remaining
                    output["weeklyReset"] = q.weekly?.resetsAt?.ISO8601Format()
                    output["capturedAt"] = q.fetchedAt.ISO8601Format()
                    emit(output)
                } catch {
                    emit(["provider": provider.rawValue, "ok": false,
                          "error": (error as? QuotaError ?? .network).message])
                }
            }
            return
        }
        runApplication()
    }

    static func emit(_ object: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) { print(text) }
    }

    static func runApplication() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        if let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 { return }
        delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var status: NSStatusItem!
    private let menu = NSMenu()
    private var states: [Provider: ProviderState] = [.claude: .init(), .codex: .init()]
    private var refreshTask: Task<Void, Never>?
    private var timer: Timer?
    private var lastAttempt = Date.distantPast
    private var retryAfter: [Provider: Date] = [:]
    private var refreshing = false
    private var showedVerificationMenu = false
    private var detailsWindow: NSWindow?
    private var detailsLabel: NSTextField?
    private var detailsRefreshButton: NSButton?
    private let client = UsageClient()

    func applicationDidFinishLaunching(_ notification: Notification) {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.imagePosition = .imageOnly
        status.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        menu.delegate = self
        status.menu = menu
        updateTitle()
        rebuildMenu()
        timer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke),
            name: NSWorkspace.didWakeNotification, object: nil)
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        refreshTask?.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showDetails()
        return false
    }

    func menuNeedsUpdate(_ menu: NSMenu) { updateTitle(); rebuildMenu() }

    @objc private func tick() {
        updateTitle()
        if Date.now.timeIntervalSince(lastAttempt) >= 300 { refresh() }
    }
    @objc private func woke() { refresh() }
    @objc private func refreshNow() { refresh() }
    private func refresh() {
        guard !refreshing else { return }
        refreshing = true
        lastAttempt = .now
        rebuildMenu()
        refreshTask = Task {
            // Independent requests ensure a failed Claude read never blanks Codex, or vice versa.
            await withTaskGroup(of: (Provider, Result<QuotaSnapshot, QuotaError>).self) { group in
                for provider in Provider.allCases {
                    if let until = retryAfter[provider], until > .now { continue }
                    let client = self.client
                    group.addTask {
                        do { return (provider, .success(try await client.fetch(provider))) }
                        catch { return (provider, .failure(error as? QuotaError ?? .network)) }
                    }
                }
                for await (provider, result) in group {
                    switch result {
                    case .success(let value): states[provider]?.succeed(value); retryAfter[provider] = nil
                    case .failure(let error):
                        states[provider]?.fail(error)
                        if error == .rateLimited { retryAfter[provider] = .now.addingTimeInterval(300) }
                    }
                    updateTitle()
                }
            }
            refreshing = false
            rebuildMenu()
            if CommandLine.arguments.contains("--show-details") && detailsWindow == nil { showDetails() }
            if CommandLine.arguments.contains("--show-menu") && !showedVerificationMenu {
                showedVerificationMenu = true
                NSApp.activate(ignoringOtherApps: true)
                status.button?.performClick(nil)
            }
        }
    }

    private func updateTitle() {
        let claude = states[.claude]?.compact(at: .now) ?? "—"
        let codex = states[.codex]?.compact(at: .now) ?? "—"
        status.button?.title = ""
        status.button?.image = MenuBarBadge.image(claude: claude, codex: codex)
        status.button?.toolTip = "本周剩余额度：Claude \(claude)，Codex \(codex)。点击查看5小时额度与重置时间。† 表示旧数据。"
        status.button?.setAccessibilityLabel("QuotaBar：Claude本周剩余\(claude)，Codex本周剩余\(codex)")
        updateDetails()
    }

    private func row(_ title: String, action: Selector? = nil, enabled: Bool = true) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = enabled && action != nil
        menu.addItem(item)
    }

    private func rebuildMenu() {
        detailsRefreshButton?.isEnabled = !refreshing
        detailsRefreshButton?.title = refreshing ? "正在刷新…" : "立即刷新"
        menu.removeAllItems()
        row("QuotaBar · 本周剩余")
        row("左 Claude  ·  右 Codex")
        menu.addItem(.separator())
        for provider in Provider.allCases {
            let state = states[provider] ?? ProviderState()
            row(provider == .claude ? "Claude" : "Codex")
            row(windowText("5小时", state.snapshot?.session, state: state))
            row(windowText("本周", state.snapshot?.weekly, state: state))
            if let error = state.error { row(error.message) }
            if let snapshot = state.snapshot {
                let prefix = state.error == nil && !snapshot.isStale(at: .now) ? "更新于" : "上次成功（旧数据）"
                row("\(prefix) \(snapshot.fetchedAt.formatted(date: .omitted, time: .standard))")
            }
            menu.addItem(.separator())
        }
        row(refreshing ? "正在刷新…" : "立即刷新", action: #selector(refreshNow), enabled: !refreshing)
        row("额度详情…", action: #selector(showDetails))
        row("打开 Claude 用量页面", action: #selector(openClaude))
        row("打开 Codex 用量页面", action: #selector(openCodex))
        let startup = NSMenuItem(title: "登录时启动", action: #selector(toggleStartup), keyEquivalent: "")
        startup.target = self
        startup.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(startup)
        menu.addItem(.separator())
        row("每5分钟刷新 · † 为旧数据 · 不代表美元余额")
        row("退出 QuotaBar", action: #selector(quit))
    }

    private func windowText(_ title: String, _ window: UsageWindow?, state: ProviderState) -> String {
        guard let window else { return "  \(title)：—（未提供）" }
        if window.hasReset(at: .now) { return "  \(title)：—（已到重置时间，等待刷新）" }
        let stale = state.error != nil || (state.snapshot?.isStale(at: .now) ?? true)
        let reset = window.resetsAt.map { " · \($0.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour().minute())) 重置" } ?? ""
        return "  \(title)：剩余 \(window.remaining)%\(stale ? "†" : "")\(reset)"
    }

    @objc private func openClaude() { openURL("https://claude.ai/settings/usage") }
    @objc private func openCodex() { openURL("https://chatgpt.com/codex/settings/usage") }
    private func openURL(_ text: String) { if let url = URL(string: text) { NSWorkspace.shared.open(url) } }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func showDetails() {
        if detailsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 350),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "QuotaBar · 额度详情"
            window.isReleasedWhenClosed = false
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 18
            stack.translatesAutoresizingMaskIntoConstraints = false
            let heading = NSTextField(labelWithString: "Claude   │   Codex")
            heading.font = .systemFont(ofSize: 21, weight: .semibold)
            let label = NSTextField(wrappingLabelWithString: "")
            label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
            label.isSelectable = true
            stack.addArrangedSubview(heading)
            stack.addArrangedSubview(label)
            let refreshButton = NSButton(title: "立即刷新", target: self, action: #selector(refreshNow))
            refreshButton.isEnabled = !refreshing
            stack.addArrangedSubview(refreshButton)
            detailsRefreshButton = refreshButton
            let hint = NSTextField(wrappingLabelWithString: "本周剩余百分比，不是美元余额。每5分钟刷新。\n关闭此窗口后，菜单栏图标继续运行。")
            hint.textColor = .secondaryLabelColor
            hint.font = .systemFont(ofSize: 11)
            stack.addArrangedSubview(hint)
            if let content = window.contentView {
                content.addSubview(stack)
                NSLayoutConstraint.activate([
                    stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
                    stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
                    stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24)
                ])
            }
            detailsWindow = window
            detailsLabel = label
            window.center()
        }
        updateDetails()
        NSApp.activate(ignoringOtherApps: true)
        detailsWindow?.makeKeyAndOrderFront(nil)
    }

    private func updateDetails() {
        detailsLabel?.stringValue = Provider.allCases.map { provider in
            let state = states[provider] ?? ProviderState()
            let name = provider == .claude ? "Claude" : "Codex"
            return "\(name) · 本周剩余 \(state.compact(at: .now))\n"
                + windowText("5小时", state.snapshot?.session, state: state) + "\n"
                + windowText("本周", state.snapshot?.weekly, state: state)
                + (state.error.map { "\n  \($0.message)" } ?? "")
        }.joined(separator: "\n\n")
    }

    @objc private func toggleStartup() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "无法更改登录启动项"
            alert.informativeText = "请到系统设置 → 通用 → 登录项与扩展，检查 QuotaBar。"
            alert.runModal()
        }
    }
}
