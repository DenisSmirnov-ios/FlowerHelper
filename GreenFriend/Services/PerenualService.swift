import Foundation

struct PerenualPlantSummary: Identifiable {
    struct ImageInfo {
        let originalURL: String?
    }

    let id: Int
    let commonName: String?
    let russianName: String?
    let scientificNames: [String]
    let wfoID: String?
    let watering: String?
    let sunlight: [String]
    let image: ImageInfo?
}

struct PerenualPlantDetails {
    let id: Int
    let commonName: String?
    let russianName: String?
    let scientificNames: [String]
    let wfoID: String?
    let description: String?
    let watering: String?
    let sunlight: [String]
    let cycle: String?
    let careLevel: String?
    let indoor: Bool?
    let imageURL: String?
}

struct PerenualLookupResult: Identifiable {
    let summary: PerenualPlantSummary
    let details: PerenualPlantDetails?

    var id: Int { summary.id }

    var displayName: String {
        if let common = summary.commonName, !common.isEmpty {
            return common
        }
        return summary.scientificNames.first ?? "Unknown"
    }

    var scientificTitle: String {
        summary.scientificNames.joined(separator: ", ")
    }

    var russianTitle: String {
        details?.russianName ?? summary.russianName ?? ""
    }

    var wateringText: String {
        details?.watering ?? summary.watering ?? "Unknown"
    }

    var sunlightText: String {
        let values = details?.sunlight ?? summary.sunlight
        if values.isEmpty {
            return "Unknown"
        }
        return values.joined(separator: ", ")
    }

    var descriptionText: String {
        details?.description ?? ""
    }

    var imageURL: String? {
        details?.imageURL ?? summary.image?.originalURL
    }
}

enum PerenualServiceError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Plant not found in offline database."
        }
    }
}

final class PerenualService {
    static let shared = PerenualService()

    private init() {}

    private struct OfflinePlantRecord: Decodable {
        let id: Int
        let commonName: String
        let russianName: String
        let scientificNames: [String]
        let aliases: [String]
        let description: String
        let watering: String
        let sunlight: [String]
        let careLevel: String
        let indoor: Bool
        let imageURL: String?
    }

    private struct WFONameIndexEntry: Decodable {
        let query: String
        let wfoID: String?
        let fullNamePlain: String?
        let classificationVersion: String?
        let error: Bool

        enum CodingKeys: String, CodingKey {
            case query
            case wfoID = "wfo_id"
            case fullNamePlain = "full_name_plain"
            case classificationVersion = "classification_version"
            case error
        }
    }

    private lazy var records: [OfflinePlantRecord] = loadIndoorCatalog()

    private lazy var wfoByScientificName: [String: String] = loadWFOIndex()

    func searchPlants(query: String, page: Int = 1) async throws -> [PerenualPlantSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let source = records.sorted { lhs, rhs in
            lhs.russianName.localizedCaseInsensitiveCompare(rhs.russianName) == .orderedAscending
        }

        let matches = source.filter { item in
            if trimmed.isEmpty { return true }
            if item.commonName.lowercased().contains(trimmed) { return true }
            if item.russianName.lowercased().contains(trimmed) { return true }
            if item.scientificNames.joined(separator: " ").lowercased().contains(trimmed) { return true }
            return item.aliases.contains(where: { $0.lowercased().contains(trimmed) })
        }

        let pageSize = 20
        let from = max((page - 1) * pageSize, 0)
        let to = min(from + pageSize, matches.count)
        guard from < to else { return [] }

        return matches[from..<to].map { item in
            let wfoID = wfoByScientificName[item.scientificNames.first?.lowercased() ?? ""]
            return PerenualPlantSummary(
                id: item.id,
                commonName: item.commonName,
                russianName: item.russianName,
                scientificNames: item.scientificNames,
                wfoID: wfoID,
                watering: item.watering,
                sunlight: item.sunlight,
                image: PerenualPlantSummary.ImageInfo(originalURL: item.imageURL)
            )
        }
    }

    func loadDetails(for speciesID: Int) async throws -> PerenualPlantDetails {
        guard let item = records.first(where: { $0.id == speciesID }) else {
            throw PerenualServiceError.notFound
        }

        return PerenualPlantDetails(
            id: item.id,
            commonName: item.commonName,
            russianName: item.russianName,
            scientificNames: item.scientificNames,
            wfoID: wfoByScientificName[item.scientificNames.first?.lowercased() ?? ""],
            description: item.description,
            watering: item.watering,
            sunlight: item.sunlight,
            cycle: "perennial",
            careLevel: item.careLevel,
            indoor: item.indoor,
            imageURL: item.imageURL
        )
    }

    private func loadWFOIndex() -> [String: String] {
        guard
            let url = Bundle.main.url(forResource: "WFONameIndex", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let entries = try? JSONDecoder().decode([WFONameIndexEntry].self, from: data)
        else {
            return [:]
        }

        var map: [String: String] = [:]
        for entry in entries {
            guard !entry.error, let id = entry.wfoID else { continue }
            map[entry.query.lowercased()] = id
        }
        return map
    }

    private func loadIndoorCatalog() -> [OfflinePlantRecord] {
        guard
            let url = Bundle.main.url(forResource: "IndoorPlantsCatalog", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([OfflinePlantRecord].self, from: data)
        else {
            return []
        }
        return decoded
    }
}

enum SettingsKeys {
    static let wateringRemindersEnabled = "watering_reminders_enabled"
    static let reminderIntervalHours = "reminder_interval_hours"
    static let reminderStartHour = "reminder_start_hour"
    static let reminderStartMinute = "reminder_start_minute"
    static let appTheme = "app_theme"
}
