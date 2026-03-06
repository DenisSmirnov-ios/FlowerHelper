import Foundation

struct WateringSnapshotItem: Codable, Identifiable {
    let id: UUID
    let name: String
    let species: String
    let nextWateringDate: Date?
    let needsWateringSoon: Bool
}

struct WateringSnapshot: Codable {
    let updatedAt: Date
    let items: [WateringSnapshotItem]
}
