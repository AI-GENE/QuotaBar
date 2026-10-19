import AppKit
import Testing
@testable import QuotaCore

@MainActor
@Test func badgeHasBothBrandMarksAndNoWordmarks() {
    #expect(MenuBarBadge.hasBrandAssets)
    let badge = MenuBarBadge.image(claude: "65%", codex: "40%")
    #expect(badge.isTemplate)
    #expect(badge.size.height == 18)
    #expect(badge.size.width > 100 && badge.size.width < 155)
    #expect(badge.tiffRepresentation != nil)
    if ProcessInfo.processInfo.environment["QUOTABAR_CAPTURE_BADGE"] == "1",
       let tiff = badge.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".build/badge-preview.png"))
    }
}

@MainActor
@Test func unavailableBadgeRetainsIcons() {
    let badge = MenuBarBadge.image(claude: "—", codex: "—")
    #expect(badge.size.width > 70)
    #expect(badge.size.width < 155)
}
