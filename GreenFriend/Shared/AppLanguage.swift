import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case russian = "ru"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .russian: return "Русский"
        case .english: return "English"
        }
    }

    func label(_ ru: String, _ en: String) -> String {
        self == .russian ? ru : en
    }

    func translateWatering(_ value: String) -> String {
        let normalized = value.lowercased()

        switch self {
        case .russian:
            switch normalized {
            case "frequent", "частый": return "Частый"
            case "average", "средний": return "Средний"
            case "minimum", "редкий": return "Редкий"
            case "none", "не требуется": return "Не требуется"
            default: return value
            }
        case .english:
            switch normalized {
            case "частый": return "Frequent"
            case "средний": return "Average"
            case "редкий": return "Minimum"
            case "не требуется": return "None"
            default: return value
            }
        }
    }

    func translateSunlight(_ values: [String]) -> String {
        let mapped = values.map { value in
            let normalized = value.lowercased()
            switch self {
            case .russian:
                switch normalized {
                case "full sun", "солнце": return "Солнце"
                case "part shade", "полутень": return "Полутень"
                case "filtered shade", "рассеянный свет": return "Рассеянный свет"
                case "shade", "тень": return "Тень"
                default: return value
                }
            case .english:
                switch normalized {
                case "солнце": return "Full sun"
                case "полутень": return "Part shade"
                case "рассеянный свет": return "Filtered shade"
                case "тень": return "Shade"
                default: return value
                }
            }
        }
        return mapped.joined(separator: ", ")
    }
}
