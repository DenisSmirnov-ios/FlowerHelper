import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query private var plants: [Plant]
    @AppStorage(SettingsKeys.appTheme) private var appThemeRawValue = AppTheme.light.rawValue
    @AppStorage(SettingsKeys.wateringRemindersEnabled) private var notificationsEnabled = false
    @AppStorage(SettingsKeys.reminderIntervalHours) private var reminderIntervalHours = 6
    @AppStorage(SettingsKeys.reminderStartHour) private var reminderStartHour = 9
    @AppStorage(SettingsKeys.reminderStartMinute) private var reminderStartMinute = 0
    @State private var requestResultText = ""

    private var reminderStartTime: Binding<Date> {
        Binding<Date>(
            get: {
                let calendar = Calendar.current
                var components = calendar.dateComponents([.year, .month, .day], from: Date())
                components.hour = reminderStartHour
                components.minute = reminderStartMinute
                components.second = 0
                return calendar.date(from: components) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderStartHour = components.hour ?? 9
                reminderStartMinute = components.minute ?? 0
            }
        )
    }

    private var themeStyle: WidgetStyle {
        .minimal
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GreenFriendTheme.screenGradient(for: colorScheme, style: themeStyle).ignoresSafeArea()
                Form {
                    Section("Оформление") {
                        Picker("Тема", selection: $appThemeRawValue) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.title).tag(theme.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("Напоминания") {
                        Toggle("Включить локальные уведомления", isOn: $notificationsEnabled)
                            .tint(GreenFriendTheme.accent(for: themeStyle))
                            .onChange(of: notificationsEnabled) { _, newValue in
                                if newValue {
                                    Task {
                                        let granted = await NotificationManager.shared.requestAuthorization()
                                        requestResultText = granted ? "Доступ к уведомлениям разрешен." : "Доступ к уведомлениям отклонен."
                                        if granted {
                                            await NotificationManager.shared.rescheduleAllReminders(for: plants)
                                        } else {
                                            notificationsEnabled = false
                                        }
                                    }
                                } else {
                                    NotificationManager.shared.cancelAllWateringReminders()
                                }
                            }

                        if notificationsEnabled {
                            Stepper(
                                "Напоминать каждые \(reminderIntervalHours) ч.",
                                value: $reminderIntervalHours,
                                in: 1...24
                            )
                            .onChange(of: reminderIntervalHours) { _, _ in
                                Task {
                                    await NotificationManager.shared.rescheduleAllReminders(for: plants)
                                }
                            }

                            DatePicker(
                                "Начинать напоминания с",
                                selection: reminderStartTime,
                                displayedComponents: .hourAndMinute
                            )
                            .onChange(of: reminderStartHour) { _, _ in
                                Task {
                                    await NotificationManager.shared.rescheduleAllReminders(for: plants)
                                }
                            }
                            .onChange(of: reminderStartMinute) { _, _ in
                                Task {
                                    await NotificationManager.shared.rescheduleAllReminders(for: plants)
                                }
                            }
                        }

                        if !requestResultText.isEmpty {
                            Text(requestResultText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("Настройки")
            .task {
                if notificationsEnabled {
                    await NotificationManager.shared.rescheduleAllReminders(for: plants)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
