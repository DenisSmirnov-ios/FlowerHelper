import Foundation
import SwiftData

@Model
final class CareLog {
    @Attribute(.unique) var id: UUID
    var action: String
    var timestamp: Date
    var note: String

    var plant: Plant?

    init(
        id: UUID = UUID(),
        action: String,
        timestamp: Date = .now,
        note: String = "",
        plant: Plant? = nil
    ) {
        self.id = id
        self.action = action
        self.timestamp = timestamp
        self.note = note
        self.plant = plant
    }
}
