// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "1up",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "OneUpCore", targets: ["OneUpCore"]),
    .executable(name: "oneup-dump", targets: ["oneup-dump"]),
    .executable(name: "oneup-app", targets: ["OneUp"]),
  ],
  targets: [
    .target(name: "OneUpCore"),
    .executableTarget(name: "oneup-dump", dependencies: ["OneUpCore"]),
    .executableTarget(name: "OneUp", dependencies: ["OneUpCore"]),
    .testTarget(
      name: "OneUpCoreTests",
      dependencies: ["OneUpCore"],
      resources: [.copy("Fixtures")]
    ),
  ],
  swiftLanguageModes: [.v6]
)
