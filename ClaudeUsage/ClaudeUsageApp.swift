import SwiftUI
import AppKit

@main
struct ClaudeUsageApp: App {
    @StateObject private var usageService = UsageService()

    // Prevent App Nap from freezing our polling timer when terminal is closed
    private let activity = ProcessInfo.processInfo.beginActivity(
        options: [.userInitiated, .idleSystemSleepDisabled],
        reason: "Periodic Claude usage polling"
    )

    var body: some Scene {
        MenuBarExtra {
            DetailPopover(usageService: usageService)
        } label: {
            Image(nsImage: MenuBarRenderer.renderMenuBarImage(
                percentage: usageService.usage.sessionPercent
            ))
        }
        .menuBarExtraStyle(.window)
    }
}
