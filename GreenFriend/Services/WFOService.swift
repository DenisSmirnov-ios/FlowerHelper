import Foundation

final class WFOService {
    static let shared = WFOService()

    private let session: URLSession

    private struct LocalCatalogRecord: Decodable {
        let commonName: String
        let russianName: String
        let scientificNames: [String]
        let aliases: [String]
    }

    private struct WFOResponse: Decodable {
        struct Match: Decodable {
            let wfoID: String?
            let fullNamePlain: String?

            enum CodingKeys: String, CodingKey {
                case wfoID = "wfo_id"
                case fullNamePlain = "full_name_plain"
            }
        }

        struct Candidate: Decodable {
            let wfoID: String?
            let fullNamePlain: String?

            enum CodingKeys: String, CodingKey {
                case wfoID = "wfo_id"
                case fullNamePlain = "full_name_plain"
            }
        }

        let match: Match?
        let candidates: [Candidate]
    }

    private lazy var localCatalog: [LocalCatalogRecord] = loadLocalCatalog()

    private init(session: URLSession = .shared) {
        self.session = session
    }

    func searchPlants(query: String) async throws -> [PerenualPlantSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let candidates = russianToLatinCandidates(for: trimmed)

        for candidate in candidates {
            if let response = try await fetchMatching(name: candidate) {
                let summaries = convert(response)
                if !summaries.isEmpty {
                    return summaries
                }
            }
        }

        return []
    }

    private func fetchMatching(name: String) async throws -> WFOResponse? {
        var components = URLComponents(string: "https://list.worldfloraonline.org/matching_rest.php")
        components?.queryItems = [
            URLQueryItem(name: "input_string", value: name),
            URLQueryItem(name: "check_homonyms", value: "yes"),
            URLQueryItem(name: "check_rank", value: "yes"),
            URLQueryItem(name: "method", value: "full"),
            URLQueryItem(name: "output_format", value: "json")
        ]

        guard let url = components?.url else { return nil }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil
        }

        // WFO can prepend PHP warnings before JSON. Keep only JSON object tail.
        let cleanData: Data
        if let text = String(data: data, encoding: .utf8),
           let braceIndex = text.firstIndex(of: "{") {
            cleanData = Data(text[braceIndex...].utf8)
        } else {
            cleanData = data
        }

        return try? JSONDecoder().decode(WFOResponse.self, from: cleanData)
    }

    private func convert(_ response: WFOResponse) -> [PerenualPlantSummary] {
        var items: [PerenualPlantSummary] = []

        if let match = response.match,
           let wfoID = match.wfoID,
           let fullName = match.fullNamePlain,
           !fullName.isEmpty {
            items.append(makeSummary(wfoID: wfoID, scientificName: fullName))
        }

        let mappedCandidates = response.candidates.compactMap { candidate -> PerenualPlantSummary? in
            guard let wfoID = candidate.wfoID,
                  let fullName = candidate.fullNamePlain,
                  !fullName.isEmpty else { return nil }
            return makeSummary(wfoID: wfoID, scientificName: fullName)
        }

        items.append(contentsOf: mappedCandidates)

        var seen = Set<Int>()
        return items.filter { summary in
            guard !seen.contains(summary.id) else { return false }
            seen.insert(summary.id)
            return true
        }
    }

    private func makeSummary(wfoID: String, scientificName: String) -> PerenualPlantSummary {
        let normalized = scientificName.trimmingCharacters(in: .whitespacesAndNewlines)

        return PerenualPlantSummary(
            id: stableID(for: wfoID),
            commonName: normalized,
            russianName: nil,
            scientificNames: [normalized],
            wfoID: wfoID,
            watering: "средний",
            sunlight: ["рассеянный свет"],
            image: nil
        )
    }

    private func russianToLatinCandidates(for query: String) -> [String] {
        var values: [String] = [query]
        let lower = query.lowercased()

        for record in localCatalog {
            if record.russianName.lowercased().contains(lower)
                || record.aliases.contains(where: { $0.lowercased().contains(lower) }) {
                if let scientific = record.scientificNames.first {
                    values.append(scientific)
                }
                values.append(record.commonName)
            }
        }

        let transliterated = transliterateCyrillicToLatin(query)
        if !transliterated.isEmpty, transliterated.lowercased() != lower {
            values.append(transliterated)
        }

        var seen = Set<String>()
        return values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter {
                let key = $0.lowercased()
                guard !seen.contains(key) else { return false }
                seen.insert(key)
                return true
            }
    }

    private func transliterateCyrillicToLatin(_ input: String) -> String {
        let map: [Character: String] = [
            "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "e", "ж": "zh", "з": "z",
            "и": "i", "й": "y", "к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r",
            "с": "s", "т": "t", "у": "u", "ф": "f", "х": "kh", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "shch",
            "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya"
        ]

        var result = ""
        for ch in input.lowercased() {
            result += map[ch] ?? String(ch)
        }
        return result
    }

    private func stableID(for value: String) -> Int {
        var hash: UInt32 = 5381
        for byte in value.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt32(byte)
        }
        return Int(hash & 0x7fff_ffff)
    }

    private func loadLocalCatalog() -> [LocalCatalogRecord] {
        guard
            let url = Bundle.main.url(forResource: "IndoorPlantsCatalog", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([LocalCatalogRecord].self, from: data)
        else {
            return []
        }
        return decoded
    }
}
