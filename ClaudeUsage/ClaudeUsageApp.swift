import SwiftUI
import AppKit

@main
struct ClaudeUsageApp: App {
    @StateObject private var usageService = UsageService()
    @StateObject private var modeStore = DisplayModeStore()

    // Prevent App Nap from freezing our polling timer when terminal is closed
    private let activity = ProcessInfo.processInfo.beginActivity(
        options: [.userInitiated, .idleSystemSleepDisabled],
        reason: "Periodic Claude usage polling"
    )

    var body: some Scene {
        MenuBarExtra {
            DetailPopover(usageService: usageService, modeStore: modeStore)
        } label: {
            let pct = usageService.usage.sessionPercent
            let stale = usageService.usage.error != nil
            Image(nsImage: modeStore.effectiveMode == .compact
                  ? MenuBarRenderer.renderCompactMenuBarImage(percentage: pct, stale: stale)
                  : MenuBarRenderer.renderMenuBarImage(percentage: pct, stale: stale))
        }
        .menuBarExtraStyle(.window)
    }
}
