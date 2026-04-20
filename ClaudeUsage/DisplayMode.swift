import AppKit
import Foundation
import SwiftUI

enum DisplayMode: String, CaseIterable, Identifiable {
    case full
    case compact
    case auto

    var id: String { rawValue }
    var label: String {
        switch self {
        case .full: return "Full"
        case .compact: return "Compact"
        case .auto: return "Auto"
        }
    }
}

@MainActor
final class DisplayModeStore: ObservableObject {
    private static let key = "cu_displayMode"

    @Published var displayMode: DisplayMode {
        didSet { UserDefaults.standard.set(displayMode.rawValue, forKey: Self.key) }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.key) ?? DisplayMode.full.rawValue
        self.displayMode = DisplayMode(rawValue: raw) ?? .full
    }

    /// Resolves `.auto` to `.full` or `.compact` based on a best-effort crowding check.
    /// Re-computed on every access (SwiftUI reads it each render).
    var effectiveMode: DisplayMode {
        switch displayMode {
        case .full, .compact: return displayMode
        case .auto: return isMenuBarCrowded() ? .compact : .full
        }
    }

    /// Best-effort heuristic. macOS does not expose other apps' menu-bar widths,
    /// so we approximate: compact when the usable top-bar width (accounting for
    /// the notch via safe-area insets) is below a threshold.
    private func isMenuBarCrowded() -> Bool {
        guard let screen = NSScreen.main else { return false }
        let usable = screen.frame.width
            - screen.safeAreaInsets.left
            - screen.safeAreaInsets.right
        // Empirical threshold: on a 14" notch MBP with several menu-bar apps,
        // usable width drops well below 1100pt. Tune as needed.
        return usable < 900
    }
}
