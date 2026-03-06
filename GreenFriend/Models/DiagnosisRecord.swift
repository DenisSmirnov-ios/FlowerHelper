import Foundation
import SwiftData

@Model
final class DiagnosisRecord {
    @Attribute(.unique) var id: UUID
    var speciesPrediction: String
    var confidence: Double
    var healthStatus: String
    var recommendation: String
    var createdAt: Date

    var plant: Plant?

    init(
        id: UUID = UUID(),
        speciesPrediction: String,
        confidence: Double,
        healthStatus: String,
        recommendation: String,
        createdAt: Date = .now,
        plant: Plant? = nil
    ) {
        self.id = id
        self.speciesPrediction = speciesPrediction
        self.confidence = confidence
        self.healthStatus = healthStatus
        self.recommendation = recommendation
        self.createdAt = createdAt
        self.plant = plant
    }
}
