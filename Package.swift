// swift-tools-version: 5.9
import PackageDescription

let package = Package(name: "Pulse", platforms: [.macOS(.v13)], products: [
    .executable(name: "Pulse", targets: ["Pulse"]),
    .executable(name: "pulse-agent", targets: ["PulseAgent"])
], targets: [
    .target(name: "PulseCore"),
    .executableTarget(name: "Pulse", dependencies: ["PulseCore"]),
    .executableTarget(name: "PulseAgent", dependencies: ["PulseCore"]),
    .testTarget(name: "PulseCoreTests", dependencies: ["PulseCore"])
])
