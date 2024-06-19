// swift-tools-version:5.8

import PackageDescription

let package = Package(
  name: "WalletCore",
  platforms: [
    .macOS(.v12), .iOS(.v14)
  ],
  products: [
    .library(name: "SignerCore", type: .static, targets: ["SignerCore"]),
  ],
  dependencies: [
    .package(path: "../TKCryptoSwift"),
    .package(path: "../ton-swift")
  ],
  targets: [
    .target(name: "CoreComponents",
            dependencies: [
              .product(name: "TonSwift", package: "ton-swift"),
              .product(name: "TKCryptoSwift", package: "TKCryptoSwift"),
            ]),
    .testTarget(name: "CoreComponentsTests",
                dependencies: [
                  "CoreComponents"
                ]),
    .target(name: "SignerCore",
            dependencies: [
              .product(name: "TonSwift", package: "ton-swift"),
              .target(name: "CoreComponents")
            ],
            path: "Sources/SignerCore"),
  ]
)
