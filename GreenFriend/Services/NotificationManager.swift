import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private struct ReminderPreferences {
        let enabled: Bool
        let intervalHours: Int
        let startHour: Int
        let startMinute: Int
    }

    private let maxReminderCountPerPlant = 6

    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func scheduleWateringReminder(for plant: Plant) async {
        cancelWateringReminder(for: plant)
        guard let nextDate = plant.nextWateringDate else { return }

        let preferences = loadReminderPreferences()
        guard preferences.enabled else { return }

        let firstReminder = firstReminderDate(
            from: nextDate,
            intervalHours: preferences.intervalHours,
            startHour: preferences.startHour,
            startMinute: preferences.startMinute
        )

        let calendar = Calendar.current
        let center = UNUserNotificationCenter.current()
        let interval = TimeInterval(preferences.intervalHours * 3_600)

        for idx in 0..<maxReminderCountPerPlant {
            let fireDate = firstReminder.addingTimeInterval(interval * Double(idx))

            let content = UNMutableNotificationContent()
            content.title = "Полив сегодня"
            content.body = WateringMessaging.reminderText(for: max(dueCountFromSnapshot(), 1))
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: reminderIdentifier(for: plant.id, index: idx),
                content: content,
                trigger: trigger
            )

            try? await center.add(request)
        }
    }

    func rescheduleAllReminders(for plants: [Plant]) async {
        cancelAllWateringReminders()
        WidgetSyncService.shared.sync(plants: plants)
        let windowsillPlants = plants.filter { $0.isOnWindowsill }
        let nextPlantToWater = windowsillPlants.min { lhs, rhs in
            let left = lhs.nextWateringDate ?? .distantFuture
            let right = rhs.nextWateringDate ?? .distantFuture
            if left != right { return left < right }
            return lhs.createdAt > rhs.createdAt
        }
        guard let nextPlantToWater else { return }
        await scheduleWateringReminder(for: nextPlantToWater)
    }

    func cancelWateringReminder(for plant: Plant) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIdentifiers(for: plant.id))
    }

    func cancelAllWateringReminders() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    private func reminderIdentifiers(for plantID: UUID) -> [String] {
        var ids = ["watering-\(plantID.uuidString)"]
        ids.append(contentsOf: (0..<maxReminderCountPerPlant).map { reminderIdentifier(for: plantID, index: $0) })
        return ids
    }

    private func reminderIdentifier(for plantID: UUID, index: Int) -> String {
        "watering-\(plantID.uuidString)-r\(index)"
    }

    private func dueCountFromSnapshot() -> Int {
        let defaults = AppGroup.userDefaults
        guard
            let data = defaults.data(forKey: "watering_snapshot"),
            let snapshot = try? JSONDecoder().decode(WateringSnapshot.self, from: data)
        else {
            return 0
        }

        let threshold = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        return snapshot.items
            .filter { item in
                guard let next = item.nextWateringDate else { return false }
                return next <= threshold
            }
            .count
    }

    private func loadReminderPreferences() -> ReminderPreferences {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: SettingsKeys.wateringRemindersEnabled)
        let intervalHours = max(defaults.object(forKey: SettingsKeys.reminderIntervalHours) as? Int ?? 6, 1)
        let startHourRaw = defaults.object(forKey: SettingsKeys.reminderStartHour) as? Int ?? 9
        let startMinuteRaw = defaults.object(forKey: SettingsKeys.reminderStartMinute) as? Int ?? 0
        let startHour = min(max(startHourRaw, 0), 23)
        let startMinute = min(max(startMinuteRaw, 0), 59)
        return ReminderPreferences(
            enabled: enabled,
            intervalHours: intervalHours,
            startHour: startHour,
            startMinute: startMinute
        )
    }

    private func firstReminderDate(
        from nextWateringDate: Date,
        intervalHours: Int,
        startHour: Int,
        startMinute: Int
    ) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let safeInterval = TimeInterval(max(intervalHours, 1) * 3_600)

        var startComponents = calendar.dateComponents([.year, .month, .day], from: nextWateringDate)
        startComponents.hour = startHour
        startComponents.minute = startMinute
        startComponents.second = 0
        let configuredStart = calendar.date(from: startComponents) ?? nextWateringDate

        var first = max(nextWateringDate, configuredStart)
        if first < now {
            let delta = now.timeIntervalSince(first)
            let steps = floor(delta / safeInterval) + 1
            first = first.addingTimeInterval(steps * safeInterval)
        }

        return first
    }
}
