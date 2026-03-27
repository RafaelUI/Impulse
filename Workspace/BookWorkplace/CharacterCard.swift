import SwiftUI
import SwiftData
import PhotosUI

struct CharacterListView: View {
    var project: WritingProject
    @Binding var selectedCharacter: Character?
    @Environment(\.modelContext) private var modelContext

    @State private var isAddingCharacter = false
    @State private var newCharacterName = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(project.characters ?? [], id: \.persistentModelID) { character in
                    let isSelected = selectedCharacter?.persistentModelID == character.persistentModelID
                    Button { selectedCharacter = character } label: {
                        CharacterRowView(character: character, isSelected: isSelected)
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
                Button { isAddingCharacter = true } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color("PrimaryText"))
                }
                .popover(isPresented: $isAddingCharacter) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Новый персонаж")
                            .font(.headline)
                            .foregroundStyle(Color("PrimaryText"))
                        TextField("Имя персонажа", text: $newCharacterName)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(width: 220)
                            .glassEffect(in: .rect(cornerRadius: 8))
                            .onSubmit {
                                if !newCharacterName.trimmingCharacters(in: .whitespaces).isEmpty {
                                    addCharacter(); isAddingCharacter = false
                                }
                            }
                        HStack {
                            Button("Отмена") { newCharacterName = ""; isAddingCharacter = false }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color("SecondaryText"))
                            Spacer()
                            Button("Создать") { addCharacter(); isAddingCharacter = false }
                                .buttonStyle(.borderedProminent)
                                .disabled(newCharacterName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .padding(18)
                }
            }
        }
        .overlay {
            if (project.characters ?? []).isEmpty {
                ZStack {
                    Color("PrimaryAccent").ignoresSafeArea()
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 36))
                            .foregroundStyle(Color("SecondaryText").opacity(0.4))
                        Text("Персонажей пока нет")
                            .foregroundStyle(Color("SecondaryText"))
                        Text("Нажмите «+» чтобы добавить первого")
                            .font(.caption)
                            .foregroundStyle(Color("SecondaryText").opacity(0.6))
                    }
                }
            }
        }
    }

    private func addCharacter() {
        let name = newCharacterName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let char = Character(name: name)
        char.project = project
        project.characters = (project.characters ?? []) + [char]
        try? modelContext.save()
        selectedCharacter = char
        newCharacterName = ""
    }
}

// MARK: - Character Row

struct CharacterRowView: View {
    var character: Character
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color("AccentColor").opacity(0.15))
                    .frame(width: 36, height: 36)

                if let data = character.photoData, let img = PlatformImage(data: data) {
                    Image(platformImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Text(character.name.prefix(1))
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color("AccentColor"))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(character.name)
                    .font(.body)
                    .foregroundStyle(isSelected ? Color("AccentColor") : Color("PrimaryText"))
                if !character.role.isEmpty {
                    Text(character.role)
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryText"))
                }
            }
        }
    }
}

// MARK: - Character Card

struct CharacterCardView: View {
    @Bindable var character: Character
    var onChapterTap: (Chapter) -> Void = { _ in }
    @Environment(\.modelContext) private var modelContext

    @State private var showDeleteAlert = false
    @State private var photoItem: PhotosPickerItem? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Шапка ──────────────────────────────────────────
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [Color("AccentColor").opacity(0.25), Color("PrimaryAccent")],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                    .frame(height: 190)

                    HStack(alignment: .bottom, spacing: 16) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color("AccentColor").opacity(0.2))
                                    .frame(width: 140, height: 140)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color("AccentColor").opacity(0.35), lineWidth: 1.5)
                                    )

                                if let data = character.photoData, let img = PlatformImage(data: data) {
                                    Image(platformImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 140, height: 140)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                } else {
                                    VStack(spacing: 6) {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 30))
                                            .foregroundStyle(Color("AccentColor").opacity(0.7))
                                        Text("Добавить фото")
                                            .font(.caption2)
                                            .foregroundStyle(Color("AccentColor").opacity(0.5))
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Имя персонажа", text: $character.name)
                                .font(.system(.title2, design: .serif, weight: .semibold))
                                .textFieldStyle(.plain)

                            TextField("Роль (главный герой, злодей...)", text: $character.role)
                                .font(.subheadline)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Color("SecondaryText"))
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 34)
                }

                // ── Секции ─────────────────────────────────────────
                VStack(alignment: .leading, spacing: 24) {

                    CardSection(icon: "calendar", title: "Возраст") {
                        AgeField(age: $character.age)
                    }

                    Rectangle().fill(Color("Border")).frame(height: 0.5)

                    CardSection(icon: "eye", title: "Внешность") {
                        GrowingTextEditor(text: $character.appearance,
                                          placeholder: "Опишите внешность персонажа...")
                    }

                    Rectangle().fill(Color("Border")).frame(height: 0.5)

                    CardSection(icon: "book.closed", title: "Биография") {
                        GrowingTextEditor(text: $character.biography,
                                          placeholder: "История жизни, ключевые события...")
                    }

                    Rectangle().fill(Color("Border")).frame(height: 0.5)

                    CardSection(icon: "bolt", title: "Способности") {
                        GrowingTextEditor(text: $character.abilities,
                                          placeholder: "Магия, навыки, таланты...")
                    }

                    Rectangle().fill(Color("Border")).frame(height: 0.5)

                    CharacterLocationsSection(character: character)

                    Rectangle().fill(Color("Border")).frame(height: 0.5)

                    CardSection(icon: "theatermasks", title: "Роль в сюжете") {
                        GrowingTextEditor(text: $character.plotRole,
                                          placeholder: "Какую функцию выполняет в истории...")
                    }

                    Rectangle().fill(Color("Border")).frame(height: 0.5)

                    ChapterAppearancesSection(character: character, onChapterTap: onChapterTap)

                    Rectangle().fill(Color("Border")).frame(height: 0.5)

                    CharacterTimelineSection(character: character)
                }
                .padding(24)
            }
        }
        .background(Color("PrimaryAccent"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(title: { Text("Выбрать из Фото") }, icon: { Image(systemName: "photo.on.rectangle") })
                    }

                    Button {
                        openImageFromFinder { data in character.photoData = data }
                    } label: {
                        Label(title: { Text("Выбрать файл...") }, icon: { Image(systemName: "folder") })
                    }

                    if character.photoData != nil {
                        Button(role: .destructive) {
                            character.photoData = nil
                        } label: {
                            Label(title: { Text("Удалить фото") }, icon: { Image(systemName: "photo.badge.minus") })
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label(title: { Text("Удалить персонажа") }, icon: { Image(systemName: "trash") })
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(Color("PrimaryText"))
                }
            }
        }
        .alert("Удалить персонажа?", isPresented: $showDeleteAlert) {
            Button("Удалить", role: .destructive) { deleteCharacter() }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Это действие нельзя отменить.")
        }
        .onChange(of: photoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    character.photoData = data
                }
            }
        }
    }

    private func deleteCharacter() {
        let trash = TrashItem(
            type: .character,
            projectTitle: character.project?.title ?? "",
            title: character.name.isEmpty ? "Без имени" : character.name,
            snapshot: characterSnapshot(character)
        )
        modelContext.insert(trash)
        modelContext.delete(character)
        try? modelContext.save()
    }
}

private func openImageFromFinder(onSelect: @escaping (Data) -> Void) {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.jpeg, .png, .heic, .tiff, .bmp, .gif, .webP]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.begin { response in
        guard response == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }
        onSelect(data)
    }
}

// MARK: - Supporting Views

struct CardSection<Content: View>: View {
    let icon: String
    let title: LocalizedStringKey
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color("SecondaryText"))
                .textCase(.uppercase)
                .tracking(0.8)
            content()
        }
    }
}

struct AgeField: View {
    @Binding var age: Int?
    @State private var text: String = ""

    var body: some View {
        TextField("Не указан", text: $text)
            .textFieldStyle(.plain)
            .onAppear { text = age.map { String($0) } ?? "" }
            .onChange(of: text) { _, new in age = Int(new) }
    }
}

// MARK: - Character Locations Section

struct CharacterLocationsSection: View {
    @Bindable var character: Character
    @State private var showPicker = false

    private var project: WritingProject? { character.project }

    private var allLocations: [WorldLocation] {
        project?.worldBuilding?.locations ?? []
    }

    private var availableLocations: [WorldLocation] {
        let linked = Set((character.worldLocations ?? []).map { $0.id })
        return allLocations.filter { !linked.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        CardSection(icon: "mappin.and.ellipse", title: "Локации") {
            VStack(alignment: .leading, spacing: 8) {
                if (character.worldLocations ?? []).isEmpty {
                    Text("Локаций не добавлено")
                        .font(.subheadline)
                        .foregroundStyle(Color("SecondaryText").opacity(0.6))
                        .padding(.vertical, 4)
                } else {
                    ForEach(character.worldLocations ?? [], id: \.id) { location in
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(Color("AccentColor").opacity(0.7))
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(location.name.isEmpty ? "Без названия" : location.name)
                                    .font(.subheadline)
                                    .foregroundStyle(Color("PrimaryText"))
                                if !location.type.isEmpty {
                                    Text(location.type)
                                        .font(.caption)
                                        .foregroundStyle(Color("SecondaryText"))
                                }
                            }
                            Spacer()
                            Button {
                                character.worldLocations?.removeAll { $0.id == location.id }
                                location.characters?.removeAll { $0.id == character.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color("SecondaryText"))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(Color("AccentColor").opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                Button {
                    showPicker = true
                } label: {
                    Label(title: { Text("Добавить локацию") }, icon: { Image(systemName: "plus.circle") })
                        .font(.subheadline)
                        .foregroundStyle(Color("AccentColor"))
                }
                .buttonStyle(.plain)
                .disabled(availableLocations.isEmpty)
                .popover(isPresented: $showPicker, arrowEdge: .bottom) {
                    LocationPickerPopover(locations: availableLocations) { location in
                        character.worldLocations = (character.worldLocations ?? []) + [location]
                        if !(location.characters ?? []).contains(where: { $0.id == character.id }) {
                            location.characters = (location.characters ?? []) + [character]
                        }
                        showPicker = false
                    }
                }
            }
        }
    }
}

// MARK: - Character Timeline Section

struct CharacterTimelineSection: View {
    @Bindable var character: Character
    @Environment(\.modelContext) private var modelContext
    @State private var showPicker = false

    private var project: WritingProject? { character.project }

    /// Узлы всех треков, где участвует этот персонаж
    private var linkedNodes: [(track: TimelineTrack, node: TimelineNode)] {
        guard let project else { return [] }
        return (project.timelineTracks ?? []).flatMap { track in
            track.nodes
                .filter { $0.characterIDs.contains(character.id) }
                .map { (track, $0) }
        }
    }

    /// Узлы всех треков, где персонаж ещё не участвует
    private var availableNodes: [(track: TimelineTrack, node: TimelineNode)] {
        guard let project else { return [] }
        return (project.timelineTracks ?? []).flatMap { track in
            track.nodes
                .filter { !$0.characterIDs.contains(character.id) }
                .map { (track, $0) }
        }
    }

    var body: some View {
        CardSection(icon: "calendar.day.timeline.left", title: "Таймлайн") {
            VStack(alignment: .leading, spacing: 8) {
                if linkedNodes.isEmpty {
                    Text("Событий не добавлено")
                        .font(.subheadline)
                        .foregroundStyle(Color("SecondaryText").opacity(0.6))
                        .padding(.vertical, 4)
                } else {
                    ForEach(linkedNodes, id: \.node.id) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.node.eventType == .range
                                  ? "arrow.left.and.right"
                                  : "smallcircle.filled.circle")
                                .foregroundStyle(Color("AccentColor").opacity(0.8))
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.node.title.isEmpty ? "Без названия" : item.node.title)
                                    .font(.subheadline)
                                    .foregroundStyle(Color("PrimaryText"))
                                Text(item.track.title.isEmpty ? "Без названия" : item.track.title)
                                    .font(.caption)
                                    .foregroundStyle(Color("SecondaryText"))
                            }
                            Spacer()
                            Button {
                                unlinkNode(trackID: item.track.id, nodeID: item.node.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color("SecondaryText"))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(Color("AccentColor").opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                Button {
                    showPicker = true
                } label: {
                    Label(title: { Text("Добавить событие") }, icon: { Image(systemName: "plus.circle") })
                        .font(.subheadline)
                        .foregroundStyle(Color("AccentColor"))
                }
                .buttonStyle(.plain)
                .disabled(availableNodes.isEmpty)
                .popover(isPresented: $showPicker, arrowEdge: .bottom) {
                    CharacterTimelineNodePickerPopover(items: availableNodes) { track, node in
                        linkNode(trackID: track.id, nodeID: node.id)
                        showPicker = false
                    }
                }
            }
        }
    }

    private func linkNode(trackID: UUID, nodeID: UUID) {
        guard let track = (project?.timelineTracks ?? []).first(where: { $0.id == trackID }) else { return }
        var nodes = track.nodes
        guard let idx = nodes.firstIndex(where: { $0.id == nodeID }) else { return }
        if !nodes[idx].characterIDs.contains(character.id) {
            nodes[idx].characterIDs.append(character.id)
            track.nodes = nodes
            try? modelContext.save()
        }
    }

    private func unlinkNode(trackID: UUID, nodeID: UUID) {
        guard let track = (project?.timelineTracks ?? []).first(where: { $0.id == trackID }) else { return }
        var nodes = track.nodes
        guard let idx = nodes.firstIndex(where: { $0.id == nodeID }) else { return }
        nodes[idx].characterIDs.removeAll { $0 == character.id }
        track.nodes = nodes
        try? modelContext.save()
    }
}

private struct CharacterTimelineNodePickerPopover: View {
    var items: [(track: TimelineTrack, node: TimelineNode)]
    var onSelect: (TimelineTrack, TimelineNode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Выберите событие")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(items, id: \.node.id) { item in
                        Button {
                            onSelect(item.track, item.node)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: item.node.eventType == .range
                                      ? "arrow.left.and.right"
                                      : "smallcircle.filled.circle")
                                    .foregroundStyle(Color("AccentColor"))
                                    .frame(width: 16)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.node.title.isEmpty ? "Без названия" : item.node.title)
                                        .font(.body)
                                        .foregroundStyle(Color("PrimaryText"))
                                    Text(item.track.title.isEmpty ? "Без названия" : item.track.title)
                                        .font(.caption)
                                        .foregroundStyle(Color("SecondaryText"))
                                }
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
        .frame(minWidth: 280)
        .background(Color("PrimaryAccent"))
    }
}

struct GrowingTextEditor: View {
    @Binding var text: String
    var placeholder: LocalizedStringKey

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(Color("SecondaryText").opacity(0.6))
                    .padding(.top, 4)
                    .padding(.leading, 4)
            }
            TextEditor(text: $text)
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
        }
        .font(.system(.body, design: .serif))
    }
}
// MARK: - Trash Snapshot

private func characterSnapshot(_ c: Character) -> String {
    var lines: [String] = []
    lines.append("Имя: \(c.name)")
    if let age = c.age { lines.append("Возраст: \(age)") }
    if !c.role.isEmpty       { lines.append("Роль: \(c.role)") }
    if !c.appearance.isEmpty { lines.append("\n— Внешность —\n\(c.appearance)") }
    if !c.biography.isEmpty  { lines.append("\n— Биография —\n\(c.biography)") }
    if !c.abilities.isEmpty  { lines.append("\n— Способности —\n\(c.abilities)") }
    if !c.plotRole.isEmpty   { lines.append("\n— Роль в сюжете —\n\(c.plotRole)") }
    return lines.joined(separator: "\n")
}

