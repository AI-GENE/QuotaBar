// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "QuotaBar",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "QuotaBar", targets: ["QuotaBar"])],
    targets: [
        .target(name: "QuotaCore", resources: [.process("Resources")]),
        .executableTarget(name: "QuotaBar", dependencies: ["QuotaCore"],
                          swiftSettings: [.defaultIsolation(MainActor.self)]),
        .testTarget(name: "QuotaCoreTests", dependencies: ["QuotaCore"])
    ]
)
