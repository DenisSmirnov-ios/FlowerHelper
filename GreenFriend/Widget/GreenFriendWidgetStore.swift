#if canImport(WidgetKit)
import Foundation

enum GreenFriendWidgetStore {
    private static let snapshotKey = "watering_snapshot"

    static func loadSnapshot() -> WateringSnapshot? {
        let defaults = AppGroup.userDefaults
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WateringSnapshot.self, from: data)
    }
}
#endif
