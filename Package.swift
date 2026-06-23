// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "CanopyManager",
  platforms: [.macOS(.v14)],
  dependencies: [],
  targets: [
    .executableTarget(
      name: "CanopyManager",
      path: "Sources/CanopyManager"
    )
  ]
)
