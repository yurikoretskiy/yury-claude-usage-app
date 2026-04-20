// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeUsage",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeUsage",
            path: "ClaudeUsage",
            resources: [
                .copy("Resources/claude-logo.png"),
                .copy("Resources/claudecode-color.png"),
                .copy("Resources/compact-mascot.png")
            ]
        )
    ]
)
