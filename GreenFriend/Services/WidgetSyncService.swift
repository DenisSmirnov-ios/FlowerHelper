import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

final class WidgetSyncService {
    static let shared = WidgetSyncService()

    private let snapshotKey = "watering_snapshot"

    private init() {}

    func sync(plants: [Plant]) {
        let items = plants
            .filter { $0.isOnWindowsill }
            .map {
                WateringSnapshotItem(
                    id: $0.id,
                    name: $0.name,
                    species: $0.species,
                    nextWateringDate: $0.nextWateringDate,
                    needsWateringSoon: $0.needsWateringSoon
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.nextWateringDate, rhs.nextWateringDate) {
                case let (.some(lDate), .some(rDate)):
                    return lDate < rDate
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return lhs.name < rhs.name
                }
            }

        let payload = WateringSnapshot(updatedAt: .now, items: items)
        guard let data = try? JSONEncoder().encode(payload) else { return }

        let defaults = AppGroup.userDefaults
        defaults.set(data, forKey: snapshotKey)
        defaults.synchronize()

#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "GreenFriendWateringWidget")
        WidgetCenter.shared.reloadAllTimelines()
#endif
    }

    func loadSnapshot() -> WateringSnapshot? {
        let defaults = AppGroup.userDefaults
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WateringSnapshot.self, from: data)
    }
}
