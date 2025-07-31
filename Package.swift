// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Olas",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    dependencies: [
        .package(path: "../NDKSwift"),
        .package(url: "https://github.com/zeugmaster/CashuSwift.git", from: "0.1.0")
    ],
    targets: [
        .executableTarget(
            name: "Olas",
            dependencies: [
                .product(name: "NDKSwift", package: "NDKSwift"),
                .product(name: "NDKSwiftUI", package: "NDKSwift"),
                .product(name: "CashuSwift", package: "CashuSwift")
            ],
            path: "Olas"
        )
    ]
)