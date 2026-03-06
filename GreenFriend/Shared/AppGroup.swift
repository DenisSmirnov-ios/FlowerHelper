import Foundation
import SwiftUI

enum AppGroup {
    static let id = "group.com.dvsmirnov.GreenFriend"
    static let userDefaults: UserDefaults = {
        UserDefaults(suiteName: id) ?? .standard
    }()
}

enum AppTheme: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "Светлая"
        case .dark: return "Темная"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum WidgetPreferences {
    static let styleKey = "widget_style"
}

enum WidgetStyle: String, CaseIterable, Identifiable {
    case glass
    case minimal
    case contrast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glass: return "Glass"
        case .minimal: return "Minimal"
        case .contrast: return "Contrast"
        }
    }
}

enum WateringMessaging {
    static func reminderText(for count: Int) -> String {
        if count <= 1 {
            return "Цветок на вашем подоконнике ждет полива"
        }
        if count > 10 {
            return "Цветы на вашем подоконнике ждут полива"
        }
        return "\(count) \(flowersWord(for: count)) на вашем подоконнике ждут полива"
    }

    private static func flowersWord(for count: Int) -> String {
        let remainder100 = count % 100
        if (11...14).contains(remainder100) { return "цветков" }
        switch count % 10 {
        case 2...4: return "цветка"
        default: return "цветков"
        }
    }
}
