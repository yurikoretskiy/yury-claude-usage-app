import Foundation
import SwiftUI

enum WidgetStyle: String, CaseIterable, Identifiable {
    case native
    case glass

    var id: String { rawValue }
    var label: String {
        switch self {
        case .native: return "Current"
        case .glass: return "Liquid Glass"
        }
    }
}

@MainActor
final class WidgetStyleStore: ObservableObject {
    private static let key = "cu_widgetStyle"

    @Published var style: WidgetStyle {
        didSet { UserDefaults.standard.set(style.rawValue, forKey: Self.key) }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.key) ?? WidgetStyle.native.rawValue
        self.style = WidgetStyle(rawValue: raw) ?? .native
    }
}
