#if canImport(WidgetKit)
import WidgetKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private enum GreenFriendWidgetTheme {
    static let accent = Color(red: 0.26, green: 0.52, blue: 0.90)
    static let warning = Color(red: 0.88, green: 0.26, blue: 0.24)

    static func backgroundGradient(for scheme: ColorScheme, style: WidgetStyle) -> LinearGradient {
        if style == .contrast {
            return LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.12, blue: 0.16),
                    Color(red: 0.16, green: 0.20, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        if style == .minimal {
            return LinearGradient(
                colors: [
                    scheme == .dark ? Color.black.opacity(0.32) : Color.white.opacity(0.54),
                    scheme == .dark ? Color.black.opacity(0.22) : Color.white.opacity(0.40)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        if scheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.14, blue: 0.19).opacity(0.78),
                    Color(red: 0.10, green: 0.18, blue: 0.24).opacity(0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color(red: 0.86, green: 0.94, blue: 0.98).opacity(0.70),
                Color(red: 0.92, green: 0.97, blue: 0.95).opacity(0.62)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func card(for scheme: ColorScheme, style: WidgetStyle) -> Color {
        if style == .contrast {
            return scheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.90)
        }
        if style == .minimal {
            return scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.34)
        }
        return scheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.42)
    }
}

struct GreenFriendWateringEntry: TimelineEntry {
    let date: Date
    let snapshot: WateringSnapshot
}

struct GreenFriendWateringProvider: TimelineProvider {
    func placeholder(in context: Context) -> GreenFriendWateringEntry {
        GreenFriendWateringEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (GreenFriendWateringEntry) -> Void) {
        let snapshot = GreenFriendWidgetStore.loadSnapshot() ?? .placeholder
        completion(GreenFriendWateringEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GreenFriendWateringEntry>) -> Void) {
        let snapshot = GreenFriendWidgetStore.loadSnapshot() ?? .placeholder
        let entry = GreenFriendWateringEntry(date: .now, snapshot: snapshot)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct GreenFriendWateringWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetFamily) private var family
    var entry: GreenFriendWateringProvider.Entry

    private var widgetStyle: WidgetStyle {
        let defaults = AppGroup.userDefaults
        let raw = defaults.string(forKey: WidgetPreferences.styleKey)
        return WidgetStyle(rawValue: raw ?? "") ?? .glass
    }

    private var dueCount: Int {
        let threshold = Calendar.current.date(byAdding: .day, value: 1, to: entry.date) ?? entry.date
        return entry.snapshot.items
            .filter { item in
                guard let next = item.nextWateringDate else { return false }
                return next <= threshold
            }
            .count
    }

    private var primaryTextColor: Color {
        Color(red: 0.08, green: 0.13, blue: 0.20)
    }

    private var gradientOverlayOpacity: Double {
        if !hasBackgroundImage { return 1 }
        switch family {
        case .systemSmall: return 0.20
        case .systemMedium: return 0.28
        default: return 0.26
        }
    }

    private var imageOpacity: Double {
        switch family {
        case .systemSmall:
            return widgetStyle == .contrast ? 0.74 : 0.64
        case .systemMedium:
            return widgetStyle == .contrast ? 0.66 : 0.56
        default:
            return widgetStyle == .contrast ? 0.68 : 0.58
        }
    }

    private var imageLightOverlayOpacity: Double {
        switch family {
        case .systemSmall:
            return colorScheme == .dark ? 0.08 : 0.16
        case .systemMedium:
            return colorScheme == .dark ? 0.10 : 0.18
        default:
            return colorScheme == .dark ? 0.10 : 0.18
        }
    }

    private var hasBackgroundImage: Bool {
        backgroundUIImage(for: family) != nil
    }

    private var contentTopPadding: CGFloat {
        switch family {
        case .systemSmall: return 11
        case .systemMedium: return 40
        default: return 12
        }
    }

    private var contentBottomPadding: CGFloat {
        switch family {
        case .systemSmall: return 12
        case .systemMedium: return 47
        default: return 14
        }
    }

    private var messageFont: Font {
        switch family {
        case .systemSmall:
            return .caption.weight(.semibold)
        case .systemMedium:
            return .footnote.weight(.semibold)
        default:
            return .subheadline.weight(.semibold)
        }
    }

    private func backgroundUIImage(for family: WidgetFamily) -> UIImage? {
#if canImport(UIKit)
        let names: [String]
        switch family {
        case .systemSmall:
            names = ["WidgetBackgroundSmall", "WidgetBackground", "widget"]
        case .systemMedium:
            names = ["WidgetBackgroundMedium", "WidgetBackground", "widget"]
        default:
            names = ["WidgetBackground", "widget"]
        }

        for name in names {
            if let named = UIImage(named: name, in: Bundle.main, compatibleWith: nil) {
                return named
            }
        }

        let extCandidates = ["jpg", "jpeg", "png"]
        for name in names {
            for ext in extCandidates {
                if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                return image
            }
        }
        }
        return nil
#else
        return nil
#endif
    }

    var body: some View {
        ZStack {
            backgroundPhotoLayer

            GreenFriendWidgetTheme.backgroundGradient(for: colorScheme, style: widgetStyle)
                .opacity(gradientOverlayOpacity)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            GreenFriendWidgetTheme.accent.opacity(colorScheme == .dark ? 0.18 : 0.16),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: family == .systemSmall ? 120 : 170, height: family == .systemSmall ? 120 : 170)
                .offset(x: family == .systemSmall ? 44 : 74, y: -44)
                .blur(radius: 6)
                .opacity(widgetStyle == .minimal ? 0.35 : 1)

            VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(GreenFriendWidgetTheme.accent)
                    Text("Полив")
                        .font(family == .systemSmall ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if dueCount == 0 {
                    Text("Ваши цветочки не требуют полива сегодня")
                        .font(.caption)
                        .foregroundStyle(primaryTextColor.opacity(0.82))
                        .lineLimit(family == .systemSmall ? 2 : 1)
                        .minimumScaleFactor(0.9)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .offset(y: family == .systemSmall ? 1 : 0)
                } else {
                    Text(WateringMessaging.reminderText(for: dueCount))
                        .font(messageFont)
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(family == .systemMedium ? 2 : 3)
                        .minimumScaleFactor(family == .systemMedium ? 0.82 : 1)
                        .allowsTightening(true)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .offset(y: family == .systemSmall ? 6 : 0)
                }
            }
            .padding(.horizontal, family == .systemSmall ? 10 : 12)
            .padding(.top, contentTopPadding)
            .padding(.bottom, contentBottomPadding)
        }
        .containerBackground(for: .widget) {
            backgroundPhotoBackground
        }
    }

    @ViewBuilder
    private var backgroundPhotoLayer: some View {
#if canImport(UIKit)
        if let image = backgroundUIImage(for: family) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .opacity(imageOpacity)
                .overlay(Color.white.opacity(imageLightOverlayOpacity))
        }
#endif
    }

    @ViewBuilder
    private var backgroundPhotoBackground: some View {
#if canImport(UIKit)
        if let image = backgroundUIImage(for: family) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            GreenFriendWidgetTheme.backgroundGradient(for: colorScheme, style: widgetStyle)
        }
#else
        GreenFriendWidgetTheme.backgroundGradient(for: colorScheme, style: widgetStyle)
#endif
    }
}

struct GreenFriendWateringWidget: Widget {
    let kind: String = "GreenFriendWateringWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GreenFriendWateringProvider()) { entry in
            GreenFriendWateringWidgetView(entry: entry)
        }
        .configurationDisplayName("Полив сегодня")
        .description("Показывает растения, которые нужно полить в ближайшее время.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private extension WateringSnapshot {
    static var placeholder: WateringSnapshot {
        WateringSnapshot(
            updatedAt: .now,
            items: [
                WateringSnapshotItem(
                    id: UUID(),
                    name: "Фикус",
                    species: "Ficus elastica",
                    nextWateringDate: .now,
                    needsWateringSoon: true
                )
            ]
        )
    }
}
#endif
