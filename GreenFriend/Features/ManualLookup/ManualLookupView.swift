import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ManualLookupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var query = ""
    @State private var isLoading = false
    @State private var errorText = ""
    @State private var results: [PerenualLookupResult] = []
    @State private var selectedResult: PerenualLookupResult?
    @State private var showAddedAlert = false
    @State private var addedPlantName = ""

    var onBackToWindowsill: () -> Void = {}

    private var language: AppLanguage {
        .russian
    }

    private var themeStyle: WidgetStyle {
        .minimal
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GreenFriendTheme.screenGradient(for: colorScheme, style: themeStyle).ignoresSafeArea()
                VStack(spacing: 12) {
                    searchBar

                    if isLoading {
                        Spacer()
                        ProgressView(language.label("Поиск...", "Searching..."))
                        Spacer()
                    } else if !errorText.isEmpty {
                        Spacer()
                        ContentUnavailableView(
                            language.label("Ошибка запроса", "Request Error"),
                            systemImage: "exclamationmark.triangle",
                            description: Text(errorText)
                        )
                        Spacer()
                    } else if results.isEmpty {
                        Spacer()
                        ContentUnavailableView(
                            language.label("Введите название растения", "Enter a plant name"),
                            systemImage: "magnifyingglass",
                            description: Text(language.label("Список пуст. Попробуйте изменить запрос.", "The list is empty. Try another query."))
                        )
                        Spacer()
                    } else {
                        List(results) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 10) {
                                    PlantPhotoView(
                                        customImageData: nil,
                                        referenceImageURL: item.imageURL,
                                        size: 58,
                                        cornerRadius: 10
                                    )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.displayName)
                                            .font(.headline)

                                        if !item.russianTitle.isEmpty {
                                            Text(item.russianTitle)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }

                                        if !item.scientificTitle.isEmpty {
                                            Text(item.scientificTitle)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }

                                if let wfoID = item.details?.wfoID ?? item.summary.wfoID {
                                    Text("WFO: \(wfoID)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                HStack {
                                    Label(language.label("Полив", "Watering"), systemImage: "drop")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(language.translateWatering(item.wateringText))
                                        .font(.caption)
                                }

                                HStack(alignment: .top) {
                                    Label(language.label("Свет", "Sunlight"), systemImage: "sun.max")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(language.translateSunlight(item.details?.sunlight ?? item.summary.sunlight))
                                        .font(.caption)
                                        .multilineTextAlignment(.trailing)
                                }

                                if !item.descriptionText.isEmpty {
                                    Text(item.descriptionText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                }

                                Button(language.label("Добавить на подоконник", "Add to windowsill")) {
                                    selectedResult = item
                                }
                                .buttonStyle(GreenFriendPrimaryButtonStyle(style: themeStyle))
                                .font(.caption)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(GreenFriendTheme.surface(for: colorScheme, style: themeStyle))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(GreenFriendTheme.stroke(for: colorScheme, style: themeStyle), lineWidth: 1)
                            }
                            .shadow(color: GreenFriendTheme.shadow(for: colorScheme, style: themeStyle), radius: 8, y: 4)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    Task { @MainActor in
                                        await quickAddToWindowsill(item)
                                    }
                                } label: {
                                    Label(language.label("Добавить", "Add"), systemImage: "plus")
                                }
                                .tint(GreenFriendTheme.accent(for: themeStyle))
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle(language.label("Поиск растения", "Plant Lookup"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onBackToWindowsill()
                    } label: {
                        Label(language.label("Подоконник", "Windowsill"), systemImage: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(GreenFriendTheme.surfaceStrong(for: colorScheme, style: themeStyle)))
                    }
                }
            }
            .sheet(item: $selectedResult) { item in
                AddPerenualPlantSheet(result: item, language: language) { plant in
                    modelContext.insert(plant)
                    try? modelContext.save()
                    addedPlantName = plant.name
                    showAddedAlert = true
                    syncWidgetSnapshot()
                    Task { @MainActor in
                        await PlantImageService.shared.resolveAndCacheImageIfNeeded(for: plant, modelContext: modelContext)
                        syncWidgetSnapshot()
                    }
                }
            }
            .alert(language.label("Добавлено", "Added"), isPresented: $showAddedAlert) {
                Button(language.label("ОК", "OK"), role: .cancel) {}
            } message: {
                Text(language.label("Растение \"\(addedPlantName)\" добавлено на подоконник.", "Plant \"\(addedPlantName)\" was added to your windowsill."))
            }
            .task {
                await search()
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(language.label("Название растения", "Plant name"), text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit {
                        Task { await search() }
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(GreenFriendTheme.surfaceStrong(for: colorScheme, style: themeStyle))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(GreenFriendTheme.stroke(for: colorScheme, style: themeStyle), lineWidth: 1)
            }

            Button(language.label("Найти", "Search")) {
                Task { await search() }
            }
            .buttonStyle(GreenFriendPrimaryButtonStyle(style: themeStyle))
            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.top, 8)
        .padding(.horizontal, 12)
    }

    @MainActor
    private func search() async {
        errorText = ""
        results = []

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        isLoading = true
        defer { isLoading = false }

        do {
            let summaries = try await PerenualService.shared.searchPlants(query: trimmed)
            if summaries.isEmpty && !trimmed.isEmpty {
                let wfoSummaries = try await WFOService.shared.searchPlants(query: trimmed)
                results = wfoSummaries
                    .map { PerenualLookupResult(summary: $0, details: nil) }
                    .sorted { $0.displayName < $1.displayName }
                return
            }
            let limited = Array(summaries.prefix(trimmed.isEmpty ? 70 : 20))

            let merged: [PerenualLookupResult] = try await withThrowingTaskGroup(of: PerenualLookupResult.self) { group in
                for summary in limited {
                    group.addTask {
                        let details = try? await PerenualService.shared.loadDetails(for: summary.id)
                        return PerenualLookupResult(summary: summary, details: details)
                    }
                }

                var items: [PerenualLookupResult] = []
                for try await item in group {
                    items.append(item)
                }
                return items.sorted { $0.displayName < $1.displayName }
            }

            results = merged
        } catch {
            errorText = error.localizedDescription
        }
    }

    @MainActor
    private func quickAddToWindowsill(_ item: PerenualLookupResult) async {
        let suggestedInterval = AddPerenualPlantSheet.mapWateringToInterval(item.wateringText)
        let russian = item.russianTitle
        let name = language == .russian && !russian.isEmpty ? russian : item.displayName
        let species = item.scientificTitle.isEmpty ? item.displayName : item.scientificTitle

        let plant = Plant(
            name: name,
            species: species,
            roomLocation: language.label("Подоконник", "Windowsill"),
            notes: "",
            wateringIntervalDays: suggestedInterval,
            wateringNotes: item.wateringText,
            sunlightRequirement: item.sunlightText,
            referenceImageURL: item.imageURL,
            customImageData: nil,
            isOnWindowsill: true
        )
        modelContext.insert(plant)
        do {
            try modelContext.save()
        } catch {
            errorText = error.localizedDescription
            return
        }
        addedPlantName = plant.name
        showAddedAlert = true
        syncWidgetSnapshot()

        await PlantImageService.shared.resolveAndCacheImageIfNeeded(for: plant, modelContext: modelContext)
        syncWidgetSnapshot()
    }

    private func syncWidgetSnapshot() {
        let descriptor = FetchDescriptor<Plant>()
        guard let allPlants = try? modelContext.fetch(descriptor) else { return }
        WidgetSyncService.shared.sync(plants: allPlants)
    }
}

private struct AddPerenualPlantSheet: View {
    @Environment(\.dismiss) private var dismiss

    let result: PerenualLookupResult
    let language: AppLanguage
    let onSave: (Plant) -> Void

    @State private var name: String
    @State private var species: String
    @State private var wateringIntervalDays: Int
    @State private var wateringNotes: String
    @State private var sunlightRequirement: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var customPhotoData: Data?
    @State private var notes: String = ""

    init(result: PerenualLookupResult, language: AppLanguage, onSave: @escaping (Plant) -> Void) {
        self.result = result
        self.language = language
        self.onSave = onSave

        let suggestedInterval = AddPerenualPlantSheet.mapWateringToInterval(result.wateringText)
        let russian = result.russianTitle
        let initialName = language == .russian && !russian.isEmpty ? russian : result.displayName
        _name = State(initialValue: initialName)
        _species = State(initialValue: result.scientificTitle.isEmpty ? result.displayName : result.scientificTitle)
        _wateringIntervalDays = State(initialValue: suggestedInterval)
        _wateringNotes = State(initialValue: result.wateringText)
        _sunlightRequirement = State(initialValue: result.sunlightText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(language.label("Основное", "Basic")) {
                    TextField(language.label("Имя", "Name"), text: $name)
                    TextField(language.label("Вид", "Species"), text: $species)
                }

                Section(language.label("Фото", "Photo")) {
                    HStack(spacing: 12) {
                        PlantPhotoView(
                            customImageData: customPhotoData,
                            referenceImageURL: result.imageURL,
                            size: 76,
                            cornerRadius: 12
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker(
                                selection: $selectedPhotoItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label(language.label("Выбрать фото", "Choose photo"), systemImage: "photo")
                            }
                            .buttonStyle(.borderedProminent)

                            if customPhotoData != nil {
                                Button(language.label("Убрать фото", "Remove photo"), role: .destructive) {
                                    selectedPhotoItem = nil
                                    customPhotoData = nil
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                Section(language.label("Уход", "Care")) {
                    Stepper(
                        language.label("Полив каждые \(wateringIntervalDays) дн.", "Water every \(wateringIntervalDays) days"),
                        value: $wateringIntervalDays,
                        in: 1...30
                    )
                    TextField(language.label("Требования к поливу", "Watering requirements"), text: $wateringNotes, axis: .vertical)
                    TextField(language.label("Требования к свету", "Sunlight requirements"), text: $sunlightRequirement, axis: .vertical)
                    TextField(language.label("Заметки", "Notes"), text: $notes, axis: .vertical)
                }
            }
            .navigationTitle(language.label("Добавить растение", "Add Plant"))
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
                    Button(language.label("Отмена", "Cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(language.label("Сохранить", "Save")) {
                        let plant = Plant(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            species: species.trimmingCharacters(in: .whitespacesAndNewlines),
                            roomLocation: language.label("Подоконник", "Windowsill"),
                            notes: notes,
                            wateringIntervalDays: wateringIntervalDays,
                            wateringNotes: wateringNotes,
                            sunlightRequirement: sunlightRequirement,
                            referenceImageURL: result.imageURL,
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

    static func mapWateringToInterval(_ value: String) -> Int {
        switch value.lowercased() {
        case "frequent", "частый": return 3
        case "average", "средний": return 7
        case "minimum", "редкий": return 14
        default: return 7
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
    ManualLookupView()
        .modelContainer(for: [Plant.self, CareLog.self, DiagnosisRecord.self], inMemory: true)
}
