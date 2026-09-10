// swift-tools-version: 5.9
import PackageDescription

let package = Package(name: "Panda", platforms: [.macOS(.v13)], products: [
    .executable(name: "Panda", targets: ["Panda"]),
    .executable(name: "panda-agent", targets: ["PandaAgent"])
], targets: [
    .target(name: "PandaCore"),
    .executableTarget(name: "Panda", dependencies: ["PandaCore"]),
    .executableTarget(name: "PandaAgent", dependencies: ["PandaCore"]),
    .testTarget(name: "PandaCoreTests", dependencies: ["PandaCore"]),
    .testTarget(name: "PandaAppTests", dependencies: ["Panda"])
])
