import Foundation
import SwiftData
import UIKit

final class PlantImageService {
    static let shared = PlantImageService()

    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.session = session
    }

    @MainActor
    func resolveAndCacheImageIfNeeded(for plant: Plant, modelContext: ModelContext) async {
        if plant.primaryDisplayPhotoData != nil { return }

        var resolvedURL = plant.referenceImageURL
        if resolvedURL == nil {
            resolvedURL = await resolveWikipediaThumbnailURL(for: plant)
            plant.referenceImageURL = resolvedURL
        }

        guard let resolvedURL,
              let imageData = await downloadImageData(from: resolvedURL)
        else {
            try? modelContext.save()
            return
        }

        plant.setGalleryPhotos([compressImageDataIfNeeded(imageData)], primaryIndex: 0)
        try? modelContext.save()
    }

    private func resolveWikipediaThumbnailURL(for plant: Plant) async -> String? {
        let candidates = candidateTitles(for: plant)
        guard candidates.isEmpty == false else { return nil }

        for title in candidates {
            if let url = await fetchThumbnailURL(for: title, languageCode: "ru") {
                return url
            }
            if let url = await fetchThumbnailURL(for: title, languageCode: "en") {
                return url
            }
        }

        return nil
    }

    private func candidateTitles(for plant: Plant) -> [String] {
        var values: [String] = []

        let cleanedSpecies = plant.species
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        values.append(contentsOf: cleanedSpecies)

        let cleanedName = plant.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedName.isEmpty {
            values.append(cleanedName)
        }

        var seen = Set<String>()
        return values.filter { value in
            let key = value.lowercased()
            guard seen.contains(key) == false else { return false }
            seen.insert(key)
            return true
        }
    }

    private func fetchThumbnailURL(for title: String, languageCode: String) async -> String? {
        let encodedTitle = title
            .replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)

        guard let encodedTitle,
              let url = URL(string: "https://\(languageCode).wikipedia.org/api/rest_v1/page/summary/\(encodedTitle)")
        else {
            return nil
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let summary = try JSONDecoder().decode(WikipediaSummaryResponse.self, from: data)
            return summary.thumbnail?.source
        } catch {
            return nil
        }
    }

    private func downloadImageData(from urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }

    private func compressImageDataIfNeeded(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }

        let maxDimension: CGFloat = 1400
        let currentMax = max(image.size.width, image.size.height)
        let outputImage: UIImage

        if currentMax > maxDimension {
            let scale = maxDimension / currentMax
            let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            outputImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        } else {
            outputImage = image
        }

        return outputImage.jpegData(compressionQuality: 0.82) ?? data
    }
}

private struct WikipediaSummaryResponse: Decodable {
    struct Thumbnail: Decodable {
        let source: String?
    }

    let thumbnail: Thumbnail?
}
