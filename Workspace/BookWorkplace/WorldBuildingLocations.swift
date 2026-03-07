import SwiftUI
import SwiftData

// MARK: - WorldBuilding: Locations

enum WorldLocationTab: String, CaseIterable, Identifiable {
    case info = "Информация"
    case artifacts = "Артефакты"
    case organizations = "Организации"
    case events = "События"
    case chapters = "Главы"
    case timeline = "Таймлайн"
    case characters = "Персонажи"

    var id: String { rawValue }
}

struct WorldBuildingLocationListView: View {
    var project: WritingProject
    @Binding var selectedLocation: WorldLocation?

    @Environment(\.modelContext) private var modelContext

    @State private var isAdding = false
    @State private var newName = ""

    private var locations: [WorldLocation] {
        project.worldBuilding?.locations.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending } ?? []
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(locations, id: \.persistentModelID) { location in
                    let isSelected = selectedLocation?.persistentModelID == location.persistentModelID
                    Button { selectedLocation = location } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(location.name.isEmpty ? "Без названия" : location.name)
                                .font(.body)
                                .foregroundStyle(isSelected ? Color("AccentColor") : Color("PrimaryText"))
                            if !location.type.isEmpty {
                                Text(location.type)
                                    .font(.caption)
                                    .foregroundStyle(Color("SecondaryText"))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(isSelected ? Color("AccentColor").opacity(0.12) : Color.clear)
                        )
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color("PrimaryAccent"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isAdding = true } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color("PrimaryText"))
                }
                .buttonStyle(AccentToolbarButtonStyle())
            }
        }
        .alert("Новая локация", isPresented: $isAdding) {
            TextField("Название", text: $newName)
            Button("Создать") { addLocation() }
            Button("Отмена", role: .cancel) { newName = "" }
        }
        .overlay {
            if locations.isEmpty {
                ZStack {
                    Color("PrimaryAccent").ignoresSafeArea()
                    VStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 36))
                            .foregroundStyle(Color("SecondaryText").opacity(0.4))
                        Text("Локаций пока нет")
                            .foregroundStyle(Color("SecondaryText"))
                        Text("Нажмите «+» чтобы добавить первую")
                            .font(.caption)
                            .foregroundStyle(Color("SecondaryText").opacity(0.6))
                    }
                }
            }
        }
        .onAppear {
            ensureWorldBuildingExists()
        }
    }

    private func ensureWorldBuildingExists() {
        guard project.worldBuilding == nil else { return }
        let world = WorldBuilding()
        world.project = project
        project.worldBuilding = world
        modelContext.insert(world)
        try? modelContext.save()
    }

    private func addLocation() {
        ensureWorldBuildingExists()
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let location = WorldLocation(name: name)
        location.worldBuilding = project.worldBuilding
        project.worldBuilding?.locations.append(location)
        modelContext.insert(location)
        try? modelContext.save()
        selectedLocation = location
        newName = ""
    }
}

// MARK: - Location Card

struct WorldBuildingLocationDetailView: View {
    @Bindable var location: WorldLocation
    @Binding var selectedTab: WorldLocationTab

    var body: some View {
        switch selectedTab {
        case .info:
            WorldBuildingLocationCardView(location: location)
        case .artifacts:
            WorldLocationTextTab(text: $location.artifacts, placeholder: "Артефакты локации...")
        case .organizations:
            WorldLocationTextTab(text: $location.organizations, placeholder: "Организации, связанные с локацией...")
        case .events:
            WorldLocationTextTab(text: $location.events, placeholder: "События, связанные с локацией...")
        case .chapters:
            WorldLocationChaptersTab(location: location)
        case .timeline:
            WorldLocationTimelineTab(location: location)
        case .characters:
            WorldLocationCharactersTab(location: location)
        }
    }
}

private struct WorldLocationTextTab: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CardSection(icon: "square.and.pencil", title: "") {
                    GrowingTextEditor(text: $text, placeholder: placeholder)
                }
                .padding(24)
            }
        }
        .background(Color("PrimaryAccent"))
    }
}

struct WorldBuildingLocationCardView: View {
    @Bindable var location: WorldLocation
    @Environment(\.modelContext) private var modelContext

    @State private var showDeleteAlert = false

    private var project: WritingProject? { location.worldBuilding?.project }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header ─────────────────────────────────────────
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [Color("AccentColor").opacity(0.25), Color("PrimaryAccent")],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                    .frame(height: 190)

                    HStack(alignment: .bottom, spacing: 16) {
                        WorldLocationPhotoView(photoData: location.photoData)

                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Название локации", text: $location.name)
                                .font(.system(.title2, design: .serif, weight: .semibold))
                                .textFieldStyle(.plain)

                            TextField("Тип (город, лес, планета...)", text: $location.type)
                                .font(.subheadline)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Color("SecondaryText"))
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 34)
                }

                // ── Sections ───────────────────────────────────────
                VStack(alignment: .leading, spacing: 24) {
                    CardSection(icon: "text.alignleft", title: "Краткое описание") {
                        GrowingTextEditor(text: $location.shortDescription,
                                          placeholder: "Одним абзацем — что это за место...")
                    }

                    Divider()

                    CardSection(icon: "sparkles", title: "Атмосфера") {
                        GrowingTextEditor(text: $location.atmosphere,
                                          placeholder: "Настроение, запахи, звук, ощущение...")
                    }

                    Divider()

                    CardSection(icon: "mountain.2", title: "География") {
                        GrowingTextEditor(text: $location.geography,
                                          placeholder: "Рельеф, климат, особенности местности...")
                    }

                    Divider()

                    WorldLocationParentSection(location: location, world: location.worldBuilding)

                    Divider()

                    WorldLocationSublocationsSection(location: location, world: location.worldBuilding)
                }
                .padding(24)
            }
        }
        .background(Color("PrimaryAccent"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Удалить локацию", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .buttonStyle(AccentToolbarButtonStyle())
            }
        }
        .alert("Удалить локацию?", isPresented: $showDeleteAlert) {
            Button("Удалить", role: .destructive) { deleteLocation() }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }

    private func deleteLocation() {
        modelContext.delete(location)
        try? modelContext.save()
    }
}

private struct WorldLocationPhotoView: View {
    let photoData: Data?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color("AccentColor").opacity(0.2))
                .frame(width: 140, height: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color("AccentColor").opacity(0.35), lineWidth: 1.5)
                )

            if let data = photoData, let img = PlatformImage(data: data) {
                Image(platformImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 30))
                    .foregroundStyle(Color("AccentColor").opacity(0.7))
            }
        }
    }
}

// MARK: - Sections

private struct WorldLocationChaptersTab: View {
    @Bindable var location: WorldLocation

    private var project: WritingProject? { location.worldBuilding?.project }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                WorldLocationChaptersSection(location: location, project: project)
                    .padding(24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("PrimaryAccent"))
    }
}

private struct WorldLocationTimelineTab: View {
    @Bindable var location: WorldLocation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                WorldLocationTimelineSection(location: location)
                    .padding(24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("PrimaryAccent"))
    }
}

private struct WorldLocationCharactersTab: View {
    @Bindable var location: WorldLocation

    private var project: WritingProject? { location.worldBuilding?.project }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                WorldLocationCharactersSection(location: location, project: project)
                    .padding(24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("PrimaryAccent"))
    }
}

private struct WorldLocationParentSection: View {
    @Bindable var location: WorldLocation
    var world: WorldBuilding?

    @State private var showPicker = false

    private var allLocations: [WorldLocation] {
        world?.locations ?? []
    }

    private var selectedParent: WorldLocation? {
        guard let parentID = location.parentID else { return nil }
        return allLocations.first(where: { $0.id == parentID })
    }

    private var availableParents: [WorldLocation] {
        let excluded: Set<UUID> = Set([location.id]).union(Set(subtreeIDs(of: location.id, in: allLocations)))
        return allLocations
            .filter { !excluded.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        CardSection(icon: "arrow.up.right", title: "Надлокации") {
            VStack(alignment: .leading, spacing: 10) {
                if let parent = selectedParent {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(parent.name.isEmpty ? "Без названия" : parent.name)
                            if !parent.type.isEmpty {
                                Text(parent.type)
                                    .font(.caption)
                                    .foregroundStyle(Color("SecondaryText"))
                            }
                        }
                        Spacer()
                        Button(role: .destructive) {
                            location.parentID = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("Не выбрано")
                        .foregroundStyle(Color("SecondaryText"))
                }

                Button {
                    showPicker = true
                } label: {
                    Label("Добавить локацию", systemImage: "plus")
                        .foregroundStyle(Color("AccentColor"))
                }
                .popover(isPresented: $showPicker) {
                    WorldLocationPickerPopover(
                        title: "Выберите надлокацию",
                        items: availableParents
                    ) { picked in
                        location.parentID = picked.id
                        showPicker = false
                    }
                    .frame(width: 360, height: 420)
                }
            }
        }
    }

    private func subtreeIDs(of rootID: UUID, in all: [WorldLocation]) -> [UUID] {
        var result: [UUID] = []
        var queue: [UUID] = [rootID]
        while let current = queue.first {
            queue.removeFirst()
            let children = all.filter { $0.parentID == current }.map { $0.id }
            for id in children where !result.contains(id) {
                result.append(id)
                queue.append(id)
            }
        }
        return result
    }
}

private struct WorldLocationSublocationsSection: View {
    @Bindable var location: WorldLocation
    var world: WorldBuilding?

    @State private var showPicker = false

    private var allLocations: [WorldLocation] {
        world?.locations ?? []
    }

    private var sublocations: [WorldLocation] {
        allLocations
            .filter { $0.parentID == location.id }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var availableSublocations: [WorldLocation] {
        let excluded = Set([location.id])
        let subTree = Set(subtreeIDs(of: location.id, in: allLocations))
        return allLocations
            .filter { !excluded.contains($0.id) }
            .filter { !subTree.contains($0.id) }
            .filter { $0.parentID != location.id }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        CardSection(icon: "arrow.down.left", title: "Подлокации") {
            VStack(alignment: .leading, spacing: 10) {
                if sublocations.isEmpty {
                    Text("Подлокации не добавлены")
                        .foregroundStyle(Color("SecondaryText"))
                } else {
                    ForEach(sublocations, id: \.id) { loc in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loc.name.isEmpty ? "Без названия" : loc.name)
                                if !loc.type.isEmpty {
                                    Text(loc.type)
                                        .font(.caption)
                                        .foregroundStyle(Color("SecondaryText"))
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                loc.parentID = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button {
                    showPicker = true
                } label: {
                    Label("Добавить локацию", systemImage: "plus")
                        .foregroundStyle(Color("AccentColor"))
                }
                .popover(isPresented: $showPicker) {
                    WorldLocationPickerPopover(
                        title: "Выберите подлокацию",
                        items: availableSublocations
                    ) { picked in
                        picked.parentID = location.id
                        showPicker = false
                    }
                    .frame(width: 360, height: 420)
                }
            }
        }
    }

    private func subtreeIDs(of rootID: UUID, in all: [WorldLocation]) -> [UUID] {
        var result: [UUID] = []
        var queue: [UUID] = [rootID]
        while let current = queue.first {
            queue.removeFirst()
            let children = all.filter { $0.parentID == current }.map { $0.id }
            for id in children where !result.contains(id) {
                result.append(id)
                queue.append(id)
            }
        }
        return result
    }
}

private struct WorldLocationPickerPopover: View {
    var title: String
    var items: [WorldLocation]
    var onSelect: (WorldLocation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(items, id: \.id) { location in
                        Button {
                            onSelect(location)
                        } label: {
                            HStack {
                                Text(location.name.isEmpty ? "Без названия" : location.name)
                                    .foregroundStyle(Color("PrimaryText"))
                                Spacer()
                                Image(systemName: "plus")
                                    .foregroundStyle(Color("AccentColor"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 320)
        }
        .frame(minWidth: 260)
    }
}

private struct WorldLocationChaptersSection: View {
    @Bindable var location: WorldLocation
    var project: WritingProject?
    @State private var showPicker = false

    private var availableChapters: [Chapter] {
        guard let project else { return [] }
        let linked = Set(location.chapters.map { $0.id })
        return project.chapters
            .filter { !linked.contains($0.id) }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        CardSection(icon: "doc.text", title: "Главы") {
            VStack(alignment: .leading, spacing: 8) {
                if location.chapters.isEmpty {
                    Text("Глав не добавлено")
                        .font(.subheadline)
                        .foregroundStyle(Color("SecondaryText").opacity(0.6))
                } else {
                    ForEach(location.chapters.sorted { $0.orderIndex < $1.orderIndex }, id: \.id) { chapter in
                        HStack {
                            Text(chapter.title.isEmpty ? "Без названия" : chapter.title)
                                .font(.subheadline)
                            Spacer()
                            Button {
                                location.chapters.removeAll { $0.id == chapter.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color("SecondaryText"))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Button {
                    showPicker = true
                } label: {
                    Label("Добавить главу", systemImage: "plus.circle")
                        .font(.subheadline)
                        .foregroundStyle(Color("AccentColor"))
                }
                .buttonStyle(.plain)
                .disabled(availableChapters.isEmpty)
                .popover(isPresented: $showPicker, arrowEdge: .bottom) {
                    WorldLocationChapterPickerPopover(chapters: availableChapters) { chapter in
                        location.chapters.append(chapter)
                        showPicker = false
                    }
                }
            }
        }
    }
}

private struct WorldLocationChapterPickerPopover: View {
    var chapters: [Chapter]
    var onSelect: (Chapter) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Выберите главу")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(chapters, id: \.id) { chapter in
                        Button {
                            onSelect(chapter)
                        } label: {
                            HStack {
                                Text(chapter.title.isEmpty ? "Без названия" : chapter.title)
                                    .foregroundStyle(Color("PrimaryText"))
                                Spacer()
                                Image(systemName: "plus")
                                    .foregroundStyle(Color("AccentColor"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 280)
        }
        .frame(minWidth: 260)
    }
}

private struct WorldLocationCharactersSection: View {
    @Bindable var location: WorldLocation
    var project: WritingProject?
    @State private var showPicker = false

    private var availableCharacters: [Character] {
        guard let project else { return [] }
        let linked = Set(location.characters.map { $0.id })
        return project.characters
            .filter { !linked.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        CardSection(icon: "person.2", title: "Персонажи") {
            VStack(alignment: .leading, spacing: 8) {
                if location.characters.isEmpty {
                    Text("Персонажей не добавлено")
                        .font(.subheadline)
                        .foregroundStyle(Color("SecondaryText").opacity(0.6))
                } else {
                    ForEach(location.characters, id: \.id) { character in
                        HStack {
                            Text(character.name)
                                .font(.subheadline)
                            Spacer()
                            Button {
                                location.characters.removeAll { $0.id == character.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color("SecondaryText"))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Button {
                    showPicker = true
                } label: {
                    Label("Добавить персонажа", systemImage: "plus.circle")
                        .font(.subheadline)
                        .foregroundStyle(Color("AccentColor"))
                }
                .buttonStyle(.plain)
                .disabled(availableCharacters.isEmpty)
                .popover(isPresented: $showPicker, arrowEdge: .bottom) {
                    WorldLocationCharacterPickerPopover(characters: availableCharacters) { character in
                        location.characters.append(character)
                        showPicker = false
                    }
                }
            }
        }
    }
}

private struct WorldLocationCharacterPickerPopover: View {
    var characters: [Character]
    var onSelect: (Character) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Выберите персонажа")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(characters, id: \.id) { character in
                        Button {
                            onSelect(character)
                        } label: {
                            HStack {
                                Text(character.name)
                                    .foregroundStyle(Color("PrimaryText"))
                                Spacer()
                                Image(systemName: "plus")
                                    .foregroundStyle(Color("AccentColor"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 280)
        }
        .frame(minWidth: 260)
    }
}

private struct WorldLocationTimelineSection: View {
    @Bindable var location: WorldLocation
    @Environment(\.modelContext) private var modelContext

    @State private var showAddAlert = false
    @State private var newTitle = ""
    @State private var newDate = ""

    private var sorted: [TimelineEvent] {
        location.timeline.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        CardSection(icon: "calendar.day.timeline.left", title: "Таймлайн") {
            VStack(alignment: .leading, spacing: 8) {
                if sorted.isEmpty {
                    Text("Событий нет")
                        .font(.subheadline)
                        .foregroundStyle(Color("SecondaryText").opacity(0.6))
                } else {
                    ForEach(sorted, id: \.id) { event in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: event.type.icon)
                                .foregroundStyle(Color("AccentColor"))
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(event.title)
                                    .font(.subheadline)
                                if !event.date.isEmpty {
                                    Text(event.date)
                                        .font(.caption)
                                        .foregroundStyle(Color("SecondaryText"))
                                }
                            }
                            Spacer()
                            Button {
                                location.timeline.removeAll { $0.id == event.id }
                                modelContext.delete(event)
                                try? modelContext.save()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color("SecondaryText"))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Button {
                    showAddAlert = true
                } label: {
                    Label("Добавить событие", systemImage: "plus.circle")
                        .font(.subheadline)
                        .foregroundStyle(Color("AccentColor"))
                }
                .buttonStyle(.plain)
            }
        }
        .alert("Новое событие", isPresented: $showAddAlert) {
            TextField("Название", text: $newTitle)
            TextField("Дата (необязательно)", text: $newDate)
            Button("Добавить") { addEvent() }
            Button("Отмена", role: .cancel) { }
        }
    }

    private func addEvent() {
        let t = newTitle.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        let event = TimelineEvent(title: t, date: newDate.trimmingCharacters(in: .whitespaces))
        event.orderIndex = location.timeline.count
        location.timeline.append(event)
        modelContext.insert(event)
        try? modelContext.save()
        newTitle = ""
        newDate = ""
    }
}

private struct WorldLocationHierarchySection: View {
    @Bindable var location: WorldLocation
    var world: WorldBuilding?
    @State private var showSubPicker = false
    @State private var showParentPicker = false

    private var allLocations: [WorldLocation] {
        world?.locations.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending } ?? []
    }

    private var parentLocation: WorldLocation? {
        guard let parentID = location.parentID else { return nil }
        return allLocations.first(where: { $0.id == parentID })
    }

    private var subLocations: [WorldLocation] {
        allLocations.filter { $0.parentID == location.id }
    }

    private var availableSubLocations: [WorldLocation] {
        allLocations.filter {
            $0.id != location.id && $0.parentID != location.id && $0.id != location.parentID
        }
    }

    private var availableParents: [WorldLocation] {
        allLocations.filter { $0.id != location.id && $0.parentID != location.id }
    }

    var body: some View {
        CardSection(icon: "point.3.connected.trianglepath.dotted", title: "Иерархия") {
            VStack(alignment: .leading, spacing: 10) {

                // Parent
                VStack(alignment: .leading, spacing: 6) {
                    Text("Надлокация")
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryText"))
                    if let parentLocation {
                        HStack {
                            Text(parentLocation.name.isEmpty ? "Без названия" : parentLocation.name)
                                .font(.subheadline)
                            Spacer()
                            Button {
                                location.parentID = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color("SecondaryText"))
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Text("Не задана")
                            .font(.subheadline)
                            .foregroundStyle(Color("SecondaryText").opacity(0.6))
                    }

                    Button {
                        showParentPicker = true
                    } label: {
                        Label("Выбрать надлокацию", systemImage: "plus.circle")
                            .font(.subheadline)
                            .foregroundStyle(Color("AccentColor"))
                    }
                    .buttonStyle(.plain)
                    .disabled(availableParents.isEmpty)
                    .popover(isPresented: $showParentPicker, arrowEdge: .bottom) {
                        WorldLocationParentPickerPopover(locations: availableParents) { parent in
                            location.parentID = parent.id
                            showParentPicker = false
                        }
                    }
                }

                Divider()

                // Children
                VStack(alignment: .leading, spacing: 6) {
                    Text("Подлокации")
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryText"))

                    if subLocations.isEmpty {
                        Text("Нет подлокаций")
                            .font(.subheadline)
                            .foregroundStyle(Color("SecondaryText").opacity(0.6))
                    } else {
                        ForEach(subLocations, id: \.id) { sub in
                            HStack {
                                Text(sub.name.isEmpty ? "Без названия" : sub.name)
                                    .font(.subheadline)
                                Spacer()
                                Button {
                                    sub.parentID = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Color("SecondaryText"))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    Button {
                        showSubPicker = true
                    } label: {
                        Label("Добавить подлокацию", systemImage: "plus.circle")
                            .font(.subheadline)
                            .foregroundStyle(Color("AccentColor"))
                    }
                    .buttonStyle(.plain)
                    .disabled(availableSubLocations.isEmpty)
                    .popover(isPresented: $showSubPicker, arrowEdge: .bottom) {
                        WorldLocationSubPickerPopover(locations: availableSubLocations) { sub in
                            sub.parentID = location.id
                            showSubPicker = false
                        }
                    }
                }
            }
        }
    }
}

private struct WorldLocationSubPickerPopover: View {
    var locations: [WorldLocation]
    var onSelect: (WorldLocation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Выберите локацию")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(locations, id: \.id) { location in
                        Button {
                            onSelect(location)
                        } label: {
                            HStack {
                                Text(location.name.isEmpty ? "Без названия" : location.name)
                                    .foregroundStyle(Color("PrimaryText"))
                                Spacer()
                                Image(systemName: "plus")
                                    .foregroundStyle(Color("AccentColor"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 280)
        }
        .frame(minWidth: 260)
    }
}

private struct WorldLocationParentPickerPopover: View {
    var locations: [WorldLocation]
    var onSelect: (WorldLocation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Выберите надлокацию")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(locations, id: \.id) { location in
                        Button {
                            onSelect(location)
                        } label: {
                            HStack {
                                Text(location.name.isEmpty ? "Без названия" : location.name)
                                    .foregroundStyle(Color("PrimaryText"))
                                Spacer()
                                Image(systemName: "plus")
                                    .foregroundStyle(Color("AccentColor"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 280)
        }
        .frame(minWidth: 260)
    }
}
