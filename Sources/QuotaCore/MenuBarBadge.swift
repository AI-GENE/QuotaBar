import AppKit

@MainActor
public enum MenuBarBadge {
    private static var bundle: Bundle {
        if let url = Bundle.main.url(forResource: "QuotaBar_QuotaCore", withExtension: "bundle"),
           let packaged = Bundle(url: url) { return packaged }
        return .module
    }

    private static let claudeLogo = logo("claude")
    private static let codexLogo = logo("codex")

    private static func logo(_ name: String) -> NSImage? {
        guard let url = bundle.url(forResource: name, withExtension: "svg"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: 64, height: 64)
        return image
    }

    public static var hasBrandAssets: Bool { claudeLogo != nil && codexLogo != nil }

    public static func image(claude: String, codex: String) -> NSImage {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.black
        ]
        let left = NSAttributedString(string: claude, attributes: attributes)
        let right = NSAttributedString(string: codex, attributes: attributes)
        let icon: CGFloat = 16, iconGap: CGFloat = 5, groupGap: CGFloat = 13
        let leftWidth = ceil(left.size().width), rightWidth = ceil(right.size().width)
        let width = icon * 2 + iconGap * 2 + groupGap + leftWidth + rightWidth
        let image = NSImage(size: NSSize(width: width, height: 18), flipped: false) { _ in
            claudeLogo?.draw(in: NSRect(x: 0, y: 1, width: icon, height: icon))
            left.draw(at: NSPoint(x: icon + iconGap, y: floor((18 - left.size().height) / 2)))
            let start = icon + iconGap + leftWidth + groupGap
            codexLogo?.draw(in: NSRect(x: start, y: 1, width: icon, height: icon))
            right.draw(at: NSPoint(x: start + icon + iconGap, y: floor((18 - right.size().height) / 2)))
            return true
        }
        image.isTemplate = true
        return image
    }
}
