import Foundation
import SwiftData

@Model
final class Plant {
    @Attribute(.unique) var id: UUID
    var name: String
    var species: String
    var roomLocation: String
    var notes: String
    var wateringIntervalDays: Int
    var wateringNotes: String
    var sunlightRequirement: String
    var referenceImageURL: String?
    var customImageData: Data?
    var photoGalleryData: Data?
    var primaryPhotoIndex: Int
    var lastWateredAt: Date?
    var manualNextWateringDate: Date?
    var isOnWindowsill: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CareLog.plant)
    var careLogs: [CareLog] = []

    @Relationship(deleteRule: .cascade, inverse: \DiagnosisRecord.plant)
    var diagnosisHistory: [DiagnosisRecord] = []

    init(
        id: UUID = UUID(),
        name: String,
        species: String,
        roomLocation: String = "",
        notes: String = "",
        wateringIntervalDays: Int = 7,
        wateringNotes: String = "",
        sunlightRequirement: String = "",
        referenceImageURL: String? = nil,
        customImageData: Data? = nil,
        photoGalleryData: Data? = nil,
        primaryPhotoIndex: Int = 0,
        lastWateredAt: Date? = nil,
        manualNextWateringDate: Date? = nil,
        isOnWindowsill: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.species = species
        self.roomLocation = roomLocation
        self.notes = notes
        self.wateringIntervalDays = wateringIntervalDays
        self.wateringNotes = wateringNotes
        self.sunlightRequirement = sunlightRequirement
        self.referenceImageURL = referenceImageURL
        self.customImageData = customImageData
        self.photoGalleryData = photoGalleryData
        self.primaryPhotoIndex = primaryPhotoIndex
        self.lastWateredAt = lastWateredAt
        self.manualNextWateringDate = manualNextWateringDate
        self.isOnWindowsill = isOnWindowsill
        self.createdAt = createdAt
    }

    var nextWateringDate: Date? {
        if let manualNextWateringDate {
            return manualNextWateringDate
        }
        guard let lastWateredAt else { return nil }
        return Calendar.current.date(byAdding: .day, value: wateringIntervalDays, to: lastWateredAt)
    }

    var needsWateringSoon: Bool {
        guard let nextWateringDate else { return true }
        return nextWateringDate <= Calendar.current.date(byAdding: .day, value: 1, to: .now)!
    }

    func galleryPhotos() -> [Data] {
        guard let photoGalleryData else { return [] }
        return (try? JSONDecoder().decode([Data].self, from: photoGalleryData)) ?? []
    }

    func setGalleryPhotos(_ photos: [Data], primaryIndex: Int? = nil) {
        photoGalleryData = try? JSONEncoder().encode(photos)

        if let primaryIndex {
            self.primaryPhotoIndex = max(0, min(primaryIndex, max(photos.count - 1, 0)))
        } else if self.primaryPhotoIndex >= photos.count {
            self.primaryPhotoIndex = max(0, photos.count - 1)
        }

        if photos.indices.contains(self.primaryPhotoIndex) {
            customImageData = photos[self.primaryPhotoIndex]
        } else if let first = photos.first {
            customImageData = first
            self.primaryPhotoIndex = 0
        } else {
            customImageData = nil
            self.primaryPhotoIndex = 0
        }
    }

    var primaryDisplayPhotoData: Data? {
        let photos = galleryPhotos()
        if photos.indices.contains(primaryPhotoIndex) {
            return photos[primaryPhotoIndex]
        }
        return customImageData
    }
}
