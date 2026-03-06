import SwiftUI
import SwiftData

enum GreenFriendTheme {
    static let warning = Color(red: 0.93, green: 0.47, blue: 0.30)

    static func accent(for style: WidgetStyle) -> Color {
        switch style {
        case .glass: return Color(red: 0.31, green: 0.66, blue: 0.76)
        case .minimal: return Color(red: 0.31, green: 0.66, blue: 0.76)
        case .contrast: return Color(red: 0.31, green: 0.66, blue: 0.76)
        }
    }

    static func accentSecondary(for style: WidgetStyle) -> Color {
        switch style {
        case .glass: return Color(red: 0.93, green: 0.86, blue: 0.48)
        case .minimal: return Color(red: 0.93, green: 0.86, blue: 0.48)
        case .contrast: return Color(red: 0.93, green: 0.86, blue: 0.48)
        }
    }

    static func screenGradient(for scheme: ColorScheme, style: WidgetStyle) -> LinearGradient {
        if style == .contrast {
            if scheme == .dark {
                return LinearGradient(
                    colors: [Color(red: 0.05, green: 0.07, blue: 0.14), Color(red: 0.09, green: 0.13, blue: 0.25)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            return LinearGradient(
                colors: [Color(red: 0.92, green: 0.95, blue: 1.0), Color(red: 0.86, green: 0.92, blue: 0.99)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if style == .minimal {
            if scheme == .dark {
                return LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.14, blue: 0.18),
                        Color(red: 0.16, green: 0.20, blue: 0.26),
                        Color(red: 0.28, green: 0.24, blue: 0.14).opacity(0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            return LinearGradient(
                colors: [Color(red: 0.82, green: 0.93, blue: 0.96), Color(red: 0.71, green: 0.86, blue: 0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        if scheme == .dark {
            return LinearGradient(
                colors: [Color(red: 0.07, green: 0.10, blue: 0.14), Color(red: 0.10, green: 0.14, blue: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Color(red: 0.94, green: 0.97, blue: 0.96), Color(red: 0.90, green: 0.94, blue: 0.98)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func surface(for scheme: ColorScheme, style: WidgetStyle) -> Color {
        if style == .contrast {
            return scheme == .dark ? Color(red: 0.13, green: 0.18, blue: 0.32).opacity(0.92) : Color.white.opacity(0.95)
        }
        if style == .minimal {
            return scheme == .dark
                ? Color(red: 0.95, green: 0.86, blue: 0.52).opacity(0.10)
                : Color.white.opacity(0.78)
        }
        return scheme == .dark
            ? Color(red: 0.14, green: 0.18, blue: 0.26).opacity(0.9)
            : Color.white.opacity(0.9)
    }

    static func surfaceStrong(for scheme: ColorScheme, style: WidgetStyle) -> Color {
        if style == .contrast {
            return scheme == .dark ? Color(red: 0.15, green: 0.22, blue: 0.38) : Color.white
        }
        if style == .minimal {
            return scheme == .dark
                ? Color(red: 0.97, green: 0.89, blue: 0.56).opacity(0.16)
                : Color.white.opacity(0.88)
        }
        return scheme == .dark
            ? Color(red: 0.18, green: 0.23, blue: 0.33)
            : Color.white.opacity(0.96)
    }

    static func stroke(for scheme: ColorScheme, style: WidgetStyle) -> Color {
        if style == .contrast {
            return scheme == .dark ? .white.opacity(0.22) : .black.opacity(0.10)
        }
        if style == .minimal {
            return scheme == .dark ? .white.opacity(0.10) : .black.opacity(0.06)
        }
        return scheme == .dark ? .white.opacity(0.14) : .black.opacity(0.08)
    }

    static func shadow(for scheme: ColorScheme, style: WidgetStyle) -> Color {
        if style == .minimal {
            return scheme == .dark ? .black.opacity(0.18) : .black.opacity(0.04)
        }
        return scheme == .dark ? .black.opacity(0.35) : .black.opacity(0.06)
    }
}

struct GreenFriendPrimaryButtonStyle: ButtonStyle {
    var style: WidgetStyle = .glass

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [GreenFriendTheme.accent(for: style), GreenFriendTheme.accentSecondary(for: style)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKeys.appTheme) private var appThemeRawValue = AppTheme.light.rawValue
    @State private var didRunPhotoBackfillThisLaunch = false

    private enum AppTab: Hashable {
        case windowsill
        case search
        case settings
    }

    @State private var selectedTab: AppTab = .windowsill

    private var themeStyle: WidgetStyle {
        .minimal
    }

    private var appTheme: AppTheme {
        AppTheme(rawValue: appThemeRawValue) ?? .light
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            WindowsillView()
                .tabItem {
                    Label("Подоконник", systemImage: "window.vertical.open")
                }
                .tag(AppTab.windowsill)

            ManualLookupView {
                selectedTab = .windowsill
            }
            .tabItem {
                Label("Поиск", systemImage: "magnifyingglass")
            }
            .tag(AppTab.search)

            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "gear")
                }
                .tag(AppTab.settings)
        }
        .tint(GreenFriendTheme.accent(for: themeStyle))
        .preferredColorScheme(appTheme.colorScheme)
        .task {
            syncWidgetSnapshot()
            AppIconService.shared.syncIcon(for: appTheme)
            await backfillPlantPhotosIfNeeded(force: false)
        }
        .onChange(of: appThemeRawValue) { _, _ in
            AppIconService.shared.syncIcon(for: appTheme)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                syncWidgetSnapshot()
                AppIconService.shared.syncIcon(for: appTheme)
                Task {
                    await backfillPlantPhotosIfNeeded(force: true)
                }
            }
        }
    }

    private func syncWidgetSnapshot() {
        let descriptor = FetchDescriptor<Plant>()
        guard let allPlants = try? modelContext.fetch(descriptor) else { return }
        WidgetSyncService.shared.sync(plants: allPlants)
    }

    @MainActor
    private func backfillPlantPhotosIfNeeded(force: Bool) async {
        if didRunPhotoBackfillThisLaunch && !force { return }
        if !didRunPhotoBackfillThisLaunch {
            didRunPhotoBackfillThisLaunch = true
        }

        let descriptor = FetchDescriptor<Plant>()
        guard let allPlants = try? modelContext.fetch(descriptor) else { return }
        let targets = allPlants.filter { ($0.customImageData == nil) && ($0.referenceImageURL == nil) }
        guard !targets.isEmpty else { return }

        for plant in targets {
            await PlantImageService.shared.resolveAndCacheImageIfNeeded(for: plant, modelContext: modelContext)
        }

        syncWidgetSnapshot()
    }
}

#Preview {
    RootTabView()
}
