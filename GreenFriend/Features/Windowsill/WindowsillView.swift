import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct WindowsillView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Plant.createdAt, order: .reverse) private var plants: [Plant]

    @State private var selectedPlant: Plant?
    @State private var plantPendingDeletion: Plant?
    @State private var showDeleteConfirmation = false
    @State private var showTodayOnly = false

    private var windowsillPlants: [Plant] {
        plants.filter { $0.isOnWindowsill }
    }

    private var themeStyle: WidgetStyle {
        .minimal
    }

    private var sortedWindowsillPlants: [Plant] {
        windowsillPlants.sorted(by: isHigherWateringPriority)
    }

    private var visiblePlants: [Plant] {
        if showTodayOnly {
            return sortedWindowsillPlants.filter(isDueToday)
        }
        return sortedWindowsillPlants
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GreenFriendTheme.screenGradient(for: colorScheme, style: themeStyle).ignoresSafeArea()
                Group {
                    if visiblePlants.isEmpty {
                        ContentUnavailableView(
                            showTodayOnly ? "Сегодня полив не нужен" : "Пустой подоконник",
                            systemImage: "window.vertical.open",
                            description: Text(
                                showTodayOnly
                                ? "На сегодня нет растений к поливу."
                                : "Добавь растения и отслеживай полив по каждому цветку."
                            )
                        )
                    } else {
                        List {
                            ForEach(visiblePlants) { plant in
                                windowsillCard(plant)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .onTapGesture {
                                        selectedPlant = plant
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            markWateringNow(for: plant)
                                        } label: {
                                            Label("Полить", systemImage: "drop.fill")
                                        }
                                        .tint(GreenFriendTheme.accentSecondary(for: themeStyle))
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            plantPendingDeletion = plant
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Удалить", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Подоконник")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showTodayOnly.toggle()
                    } label: {
                        Label("Сегодня", systemImage: "calendar.badge.clock")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(
                                        showTodayOnly
                                        ? GreenFriendTheme.accent(for: themeStyle).opacity(0.24)
                                        : GreenFriendTheme.surfaceStrong(for: colorScheme, style: themeStyle)
                                    )
                            )
                    }
                    .tint(showTodayOnly ? GreenFriendTheme.accent(for: themeStyle) : .primary)
                }
            }
            .sheet(item: $selectedPlant) { plant in
                WindowsillPlantInfoSheet(
                    plant: plant,
                    onWaterNow: {
                        markWateringNow(for: plant)
                    },
                    onSaveWateringDates: { lastDate, nextDate in
                        updateWateringDates(for: plant, lastWateredAt: lastDate, nextWateringDate: nextDate)
                    },
                    onPhotoUpdated: {
                        syncWidgetSnapshot()
                    }
                )
            }
            .alert("Удалить растение?", isPresented: $showDeleteConfirmation) {
                Button("Удалить", role: .destructive) {
                    guard let plantPendingDeletion else { return }
                    deletePlant(plantPendingDeletion)
                }
                Button("Отмена", role: .cancel) {
                    plantPendingDeletion = nil
                }
            } message: {
                Text("Растение будет удалено с подоконника.")
            }
            .task {
                syncWidgetSnapshot()
            }
        }
    }

    @ViewBuilder
    private func windowsillCard(_ plant: Plant) -> some View {
        HStack(alignment: .top, spacing: 10) {
            PlantPhotoView(
                customImageData: plant.primaryDisplayPhotoData,
                referenceImageURL: plant.referenceImageURL,
                size: 56,
                cornerRadius: 12
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(plant.name)
                    .font(.headline)
                    .lineLimit(2)

                VStack(alignment: .leading, spacing: 3) {
                    iconScaleRow(
                        title: "Полив",
                        filledSymbol: "drop.fill",
                        emptySymbol: "drop",
                        level: wateringIntensityLevel(for: plant),
                        tint: .blue
                    )

                    iconScaleRow(
                        title: "Свет",
                        filledSymbol: "sun.max.fill",
                        emptySymbol: "sun.max",
                        level: sunlightIntensityLevel(for: plant),
                        tint: .orange
                    )
                }

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let nextDate = plant.nextWateringDate {
                        Text(nextDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(
                                nextDate < .now
                                ? .red
                                : (plant.needsWateringSoon ? .orange : .secondary)
                            )
                    } else {
                        Text("Не указан")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
        .background(cardBackground(for: plant))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: GreenFriendTheme.shadow(for: colorScheme, style: themeStyle), radius: 8, y: 4)
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isOverdue(plant) ? Color.red.opacity(0.9) : Color.clear,
                    lineWidth: isOverdue(plant) ? 1.5 : 0
                )
        }
    }

    @ViewBuilder
    private func cardBackground(for plant: Plant) -> some View {
        let fill = wateringFillLevel(for: plant)

        RoundedRectangle(cornerRadius: 14)
            .fill(GreenFriendTheme.surface(for: colorScheme, style: themeStyle))
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    let progressWidth = max(0, geometry.size.width * fill)
                    RoundedRectangle(cornerRadius: 14)
                        .fill(GreenFriendTheme.accentSecondary(for: themeStyle).opacity(colorScheme == .dark ? 0.24 : 0.2))
                        .frame(width: progressWidth)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .overlay {
                if isOverdue(plant) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.red.opacity(colorScheme == .dark ? 0.24 : 0.16))
                        .blur(radius: 1.2)
                }
                RoundedRectangle(cornerRadius: 14)
                    .stroke(GreenFriendTheme.stroke(for: colorScheme, style: themeStyle), lineWidth: 1)
            }
    }

    @ViewBuilder
    private func iconScaleRow(
        title: String,
        filledSymbol: String,
        emptySymbol: String,
        level: Int,
        tint: Color
    ) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach(0..<3, id: \.self) { idx in
                Image(systemName: idx < level ? filledSymbol : emptySymbol)
                    .font(.caption2)
                    .foregroundStyle(idx < level ? tint : .secondary)
            }
        }
    }

    private func deletePlant(_ plant: Plant) {
        if selectedPlant?.id == plant.id {
            selectedPlant = nil
        }

        modelContext.delete(plant)
        try? modelContext.save()
        syncWidgetSnapshot()
        plantPendingDeletion = nil
    }

    private func isDueToday(_ plant: Plant) -> Bool {
        guard let next = plant.nextWateringDate else { return false }
        let calendar = Calendar.current
        return calendar.isDateInToday(next) || next < .now
    }

    private func isOverdue(_ plant: Plant) -> Bool {
        guard let next = plant.nextWateringDate else { return false }
        return next < .now
    }

    private func isHigherWateringPriority(_ lhs: Plant, _ rhs: Plant) -> Bool {
        let left = wateringSortKey(for: lhs)
        let right = wateringSortKey(for: rhs)

        if left.priority != right.priority {
            return left.priority < right.priority
        }
        if left.date != right.date {
            return left.date < right.date
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func wateringSortKey(for plant: Plant) -> (priority: Int, date: Date) {
        guard let next = plant.nextWateringDate else {
            return (priority: 3, date: .distantFuture)
        }

        let calendar = Calendar.current
        if next < .now {
            return (priority: 0, date: next)
        }
        if calendar.isDateInToday(next) {
            return (priority: 1, date: next)
        }
        return (priority: 2, date: next)
    }

    private func wateringIntensityLevel(for plant: Plant) -> Int {
        let days = plant.wateringIntervalDays
        switch days {
        case ...4: return 3
        case 5...8: return 2
        default: return 1
        }
    }

    private func sunlightIntensityLevel(for plant: Plant) -> Int {
        let source = plant.sunlightRequirement.lowercased()
        if source.contains("full sun") || source.contains("солнце") {
            return 3
        }
        if source.contains("part shade") || source.contains("полутень") {
            return 2
        }
        if source.contains("filtered shade") || source.contains("рассеянный") {
            return 2
        }
        if source.contains("shade") || source.contains("тень") {
            return 1
        }
        return 2
    }

    private func wateringFillLevel(for plant: Plant) -> CGFloat {
        guard let nextDate = plant.nextWateringDate else { return 0.3 }

        let now = Date()
        if now >= nextDate { return 0 }

        if let lastDate = plant.lastWateredAt, nextDate > lastDate {
            let total = nextDate.timeIntervalSince(lastDate)
            guard total > 0 else { return 0 }
            let remaining = nextDate.timeIntervalSince(now)
            return CGFloat(min(max(remaining / total, 0), 1))
        }

        let fallbackTotal = TimeInterval(max(plant.wateringIntervalDays, 1) * 86_400)
        let remaining = nextDate.timeIntervalSince(now)
        return CGFloat(min(max(remaining / fallbackTotal, 0), 1))
    }

    private func markWateringNow(for plant: Plant) {
        plant.lastWateredAt = .now
        plant.manualNextWateringDate = nil
        plant.careLogs.append(CareLog(action: "watering", note: "Полив с экрана подоконника", plant: plant))
        try? modelContext.save()

        Task {
            await NotificationManager.shared.scheduleWateringReminder(for: plant)
        }

        syncWidgetSnapshot()
    }

    private func updateWateringDates(for plant: Plant, lastWateredAt: Date?, nextWateringDate: Date?) {
        plant.lastWateredAt = lastWateredAt
        plant.manualNextWateringDate = nextWateringDate
        try? modelContext.save()

        NotificationManager.shared.cancelWateringReminder(for: plant)
        if plant.nextWateringDate != nil {
            Task {
                await NotificationManager.shared.scheduleWateringReminder(for: plant)
            }
        }

        syncWidgetSnapshot()
    }

    private func syncWidgetSnapshot() {
        let descriptor = FetchDescriptor<Plant>()
        guard let allPlants = try? modelContext.fetch(descriptor) else { return }
        WidgetSyncService.shared.sync(plants: allPlants)
    }
}

private struct WindowsillPlantInfoSheet: View {
    private static let maxPhotoSlots = 5
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let plant: Plant
    let onWaterNow: () -> Void
    let onSaveWateringDates: (Date?, Date?) -> Void
    let onPhotoUpdated: () -> Void

    @State private var selectedLastWateringDate: Date
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var slotPhotos: [Data?]
    @State private var currentSlotIndex: Int
    @State private var primarySlotIndex: Int?
    @State private var photoSlotPendingInsert: Int?
    @State private var photoIndexPendingDeletion: Int?
    @State private var showPhotoDeleteConfirmation = false
    @State private var showLastWateringPicker = false

    init(
        plant: Plant,
        onWaterNow: @escaping () -> Void,
        onSaveWateringDates: @escaping (Date?, Date?) -> Void,
        onPhotoUpdated: @escaping () -> Void
    ) {
        self.plant = plant
        self.onWaterNow = onWaterNow
        self.onSaveWateringDates = onSaveWateringDates
        self.onPhotoUpdated = onPhotoUpdated

        let now = Date()
        let initialLast = plant.lastWateredAt ?? now
        _selectedLastWateringDate = State(initialValue: initialLast)
        var initialPhotos = plant.galleryPhotos()
        if initialPhotos.isEmpty, let fallback = plant.customImageData {
            initialPhotos = [fallback]
        }
        var slots = Array<Data?>(repeating: nil, count: Self.maxPhotoSlots)
        for (idx, data) in initialPhotos.prefix(Self.maxPhotoSlots).enumerated() {
            slots[idx] = data
        }
        let hasAny = slots.contains(where: { $0 != nil })
        let boundedPrimary = max(0, min(plant.primaryPhotoIndex, Self.maxPhotoSlots - 1))
        _slotPhotos = State(initialValue: slots)
        _primarySlotIndex = State(initialValue: hasAny ? boundedPrimary : nil)
        _currentSlotIndex = State(initialValue: hasAny ? boundedPrimary : 0)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Фото") {
                    GeometryReader { geo in
                        let centerWidth = max(168, min(geo.size.width * 0.62, 230))
                        let centerHeight = 230.0
                        let sideWidth = centerWidth * 0.58
                        let sideHeight = 166.0
                        let sideOffset = centerWidth * 0.44

                        ZStack {
                            if let leftSlot = sideSlot(offset: -1) {
                                Button {
                                    handleSideSlotTap(leftSlot)
                                } label: {
                                    carouselCard(
                                        for: leftSlot,
                                        width: sideWidth,
                                        height: sideHeight,
                                        isCenter: false
                                    )
                                }
                                .buttonStyle(.plain)
                                .offset(x: -sideOffset, y: 28)
                                .zIndex(1)
                            }

                            if let rightSlot = sideSlot(offset: 1) {
                                Button {
                                    handleSideSlotTap(rightSlot)
                                } label: {
                                    carouselCard(
                                        for: rightSlot,
                                        width: sideWidth,
                                        height: sideHeight,
                                        isCenter: false
                                    )
                                }
                                .buttonStyle(.plain)
                                .offset(x: sideOffset, y: 28)
                                .zIndex(1)
                            }

                            ZStack(alignment: .topTrailing) {
                                carouselCard(
                                    for: currentSlotIndex,
                                    width: centerWidth,
                                    height: centerHeight,
                                    isCenter: true
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    handlePhotoTapOnCurrentSlot()
                                }

                                if slotPhotos[currentSlotIndex] != nil {
                                    Button(role: .destructive) {
                                        photoIndexPendingDeletion = currentSlotIndex
                                        showPhotoDeleteConfirmation = true
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(.white, .red)
                                            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                                            .frame(width: 30, height: 30)
                                            .contentShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .padding(8)
                                    .zIndex(20)
                                }
                            }
                            .zIndex(3)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .animation(.easeInOut(duration: 0.24), value: currentSlotIndex)
                    }
                    .frame(height: 250)
                }

                Section(plant.name) {
                    LabeledContent {
                        Text("Каждые \(plant.wateringIntervalDays) дн.")
                    } label: {
                        Label("Полив", systemImage: "drop.fill")
                            .foregroundStyle(.blue)
                    }
                    LabeledContent {
                        Text(localizedSunlightRequirement(plant.sunlightRequirement))
                    } label: {
                        Label("Свет", systemImage: "sun.max.fill")
                            .foregroundStyle(.orange)
                    }

                    Button {
                        showLastWateringPicker = true
                    } label: {
                        LabeledContent("Последний полив") {
                            Text(selectedLastWateringDate.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)

                    Button("Полить сейчас") {
                        onWaterNow()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle(plant.name)
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            let compressed = compressImageDataIfNeeded(data)
                            let targetSlot = photoSlotPendingInsert ?? currentSlotIndex
                            guard slotPhotos.indices.contains(targetSlot) else { return }
                            slotPhotos[targetSlot] = compressed
                            if primarySlotIndex == nil {
                                primarySlotIndex = targetSlot
                            }
                            currentSlotIndex = targetSlot
                            savePhotoGalleryImmediately()
                            photoSlotPendingInsert = nil
                            selectedPhotoItem = nil
                        }
                    }
                }
            }
            .alert("Удалить фото?", isPresented: $showPhotoDeleteConfirmation) {
                Button("Удалить", role: .destructive) {
                    guard let index = photoIndexPendingDeletion else { return }
                    deletePhoto(at: index)
                    photoIndexPendingDeletion = nil
                }
                Button("Отмена", role: .cancel) {
                    photoIndexPendingDeletion = nil
                }
            } message: {
                Text("Фото будет удалено из карточки растения.")
            }
            .photosPicker(
                isPresented: Binding(
                    get: { photoSlotPendingInsert != nil },
                    set: { isPresented in
                        if !isPresented {
                            photoSlotPendingInsert = nil
                        }
                    }
                ),
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            )
            .sheet(isPresented: $showLastWateringPicker) {
                NavigationStack {
                    Form {
                        DatePicker(
                            "Дата последнего полива",
                            selection: $selectedLastWateringDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.graphical)
                    }
                    .navigationTitle("Последний полив")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Готово") {
                                showLastWateringPicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.large])
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Назад") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        onSaveWateringDates(selectedLastWateringDate, nil)
                        dismiss()
                    }
                }
            }
        }
    }

    private func localizedSunlightRequirement(_ value: String) -> String {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard normalized.isEmpty == false else { return "-" }

        switch normalized {
        case "full sun":
            return "Солнце"
        case "part shade":
            return "Полутень"
        case "filtered shade":
            return "Рассеянный свет"
        case "shade":
            return "Тень"
        default:
            return value
        }
    }

    private func compressImageDataIfNeeded(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let maxDimension: CGFloat = 1400
        let currentMax = max(image.size.width, image.size.height)
        let targetImage: UIImage

        if currentMax > maxDimension {
            let scale = maxDimension / currentMax
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            targetImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        } else {
            targetImage = image
        }

        return targetImage.jpegData(compressionQuality: 0.82) ?? data
    }

    private func savePhotoGalleryImmediately() {
        let indexed = slotPhotos.enumerated().compactMap { idx, data -> (Int, Data)? in
            guard let data else { return nil }
            return (idx, data)
        }
        let photos = indexed.map { $0.1 }
        let primaryCompactIndex: Int
        if let primarySlotIndex,
           let compact = indexed.firstIndex(where: { $0.0 == primarySlotIndex }) {
            primaryCompactIndex = compact
        } else {
            primaryCompactIndex = 0
        }
        plant.setGalleryPhotos(photos, primaryIndex: primaryCompactIndex)
        try? modelContext.save()
        onPhotoUpdated()
    }

    private func deletePhoto(at index: Int) {
        guard slotPhotos.indices.contains(index) else { return }
        slotPhotos[index] = nil

        if primarySlotIndex == index {
            primarySlotIndex = nil
            currentSlotIndex = index
        }

        savePhotoGalleryImmediately()

        // If user removed all local photos, try restoring from online source.
        if slotPhotos.allSatisfy({ $0 == nil }) {
            Task { @MainActor in
                await PlantImageService.shared.resolveAndCacheImageIfNeeded(for: plant, modelContext: modelContext)
                reloadSlotsFromPlant()
                onPhotoUpdated()
            }
        }
    }

    private func handlePhotoTapOnCurrentSlot() {
        if slotPhotos[currentSlotIndex] != nil {
            primarySlotIndex = currentSlotIndex
            savePhotoGalleryImmediately()
        } else {
            photoSlotPendingInsert = currentSlotIndex
        }
    }

    private func reloadSlotsFromPlant() {
        var photos = plant.galleryPhotos()
        if photos.isEmpty, let fallback = plant.customImageData {
            photos = [fallback]
        }
        var slots = Array<Data?>(repeating: nil, count: Self.maxPhotoSlots)
        for (idx, data) in photos.prefix(Self.maxPhotoSlots).enumerated() {
            slots[idx] = data
        }
        slotPhotos = slots

        if let firstFilled = slots.enumerated().first(where: { $0.element != nil })?.offset {
            let preferred = min(max(plant.primaryPhotoIndex, 0), Self.maxPhotoSlots - 1)
            if slots[preferred] != nil {
                primarySlotIndex = preferred
            } else {
                primarySlotIndex = firstFilled
            }
            currentSlotIndex = primarySlotIndex ?? firstFilled
        } else {
            primarySlotIndex = nil
            currentSlotIndex = 0
        }
    }

    private func sideSlot(offset: Int) -> Int? {
        let idx = wrappedSlotIndex(currentSlotIndex + offset)
        return idx
    }

    private func wrappedSlotIndex(_ value: Int) -> Int {
        let count = Self.maxPhotoSlots
        return ((value % count) + count) % count
    }

    private func handleSideSlotTap(_ slot: Int) {
        guard slotPhotos.indices.contains(slot) else { return }
        currentSlotIndex = slot
        if slotPhotos[slot] != nil {
            primarySlotIndex = slot
            savePhotoGalleryImmediately()
        } else {
            photoSlotPendingInsert = slot
        }
    }

    @ViewBuilder
    private func carouselCard(for slotIndex: Int, width: CGFloat, height: CGFloat, isCenter: Bool) -> some View {
        ZStack {
            if let data = slotPhotos[slotIndex] {
                PlantPhotoView(
                    customImageData: data,
                    referenceImageURL: nil,
                    size: min(width, height),
                    cornerRadius: 16
                )
                .frame(width: width, height: height)
            } else {
                Image("PlantPlaceholder")
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                    .overlay {
                        ZStack {
                            Color.black.opacity(0.14)
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: isCenter ? 26 : 18, weight: .medium))
                                Text("Слот \(slotIndex + 1) / \(Self.maxPhotoSlots)")
                                    .font(isCenter ? .subheadline : .caption)
                            }
                            .foregroundStyle(.white)
                        }
                    }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    (primarySlotIndex == slotIndex && slotPhotos[slotIndex] != nil)
                    ? Color.green : Color.secondary.opacity(0.2),
                    lineWidth: (primarySlotIndex == slotIndex && slotPhotos[slotIndex] != nil) ? 3 : 1
                )
        }
    }
}

private struct WindowsillAddPlantSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var species = ""
    @State private var notes = ""
    @State private var wateringInterval = 7
    @State private var wateringNotes = ""
    @State private var sunlightRequirement = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var customPhotoData: Data?
    @State private var referenceImageURL = ""

    let onSave: (Plant) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Основное") {
                    TextField("Имя", text: $name)
                    TextField("Вид", text: $species)
                }

                Section("Фото") {
                    HStack(spacing: 12) {
                        PlantPhotoView(
                            customImageData: customPhotoData,
                            referenceImageURL: referenceImageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : referenceImageURL,
                            size: 76,
                            cornerRadius: 12
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker(
                                selection: $selectedPhotoItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label("Выбрать фото", systemImage: "photo")
                            }
                            .buttonStyle(.borderedProminent)

                            if customPhotoData != nil {
                                Button("Убрать фото", role: .destructive) {
                                    selectedPhotoItem = nil
                                    customPhotoData = nil
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    TextField("Ссылка на фото (опционально)", text: $referenceImageURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }

                Section("Уход") {
                    Stepper("Полив каждые \(wateringInterval) дн.", value: $wateringInterval, in: 2...30)
                    TextField("Требования к поливу", text: $wateringNotes, axis: .vertical)
                    TextField("Требования к свету", text: $sunlightRequirement, axis: .vertical)
                    TextField("Заметки", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("Добавить на подоконник")
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        customPhotoData = compressImageDataIfNeeded(data)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let plant = Plant(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            species: species.trimmingCharacters(in: .whitespacesAndNewlines),
                            roomLocation: "Подоконник",
                            notes: notes,
                            wateringIntervalDays: wateringInterval,
                            wateringNotes: wateringNotes,
                            sunlightRequirement: sunlightRequirement,
                            referenceImageURL: referenceImageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : referenceImageURL.trimmingCharacters(in: .whitespacesAndNewlines),
                            customImageData: customPhotoData,
                            isOnWindowsill: true
                        )
                        onSave(plant)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || species.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func compressImageDataIfNeeded(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let maxDimension: CGFloat = 1400
        let currentMax = max(image.size.width, image.size.height)
        let targetImage: UIImage

        if currentMax > maxDimension {
            let scale = maxDimension / currentMax
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            targetImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        } else {
            targetImage = image
        }

        return targetImage.jpegData(compressionQuality: 0.82) ?? data
    }
}

#Preview {
    WindowsillView()
        .modelContainer(for: [Plant.self, CareLog.self, DiagnosisRecord.self], inMemory: true)
}
