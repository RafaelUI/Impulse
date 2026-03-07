import SwiftUI
import SwiftData




// MARK: - Chapter Appearances Section

struct ChapterAppearancesSection: View {
       @State private var searchText: String = ""
    @Bindable var character: Character
    var onChapterTap: (Chapter) -> Void = { _ in }
    @State private var showChapterPicker = false

    var project: WritingProject? { character.project }

    var availableChapters: [Chapter] {
        let linked = Set(character.appearsInChapters.map { $0.id })
        return (project?.chapters ?? [])
            .filter { !linked.contains($0.id) }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        CardSection(icon: "text.book.closed", title: "Появления в главах") {
            VStack(alignment: .leading, spacing: 8) {

                if character.appearsInChapters.isEmpty {
                    Text("Ни одной главы не добавлено")
                        .font(.subheadline)
                        .foregroundStyle(Color("SecondaryText").opacity(0.6))
                        .padding(.vertical, 4)
                } else {
                    ForEach(
                        character.appearsInChapters.sorted { $0.orderIndex < $1.orderIndex },
                        id: \.id
                    ) { chapter in
                        ChapterLinkRow(
                            chapter: chapter,
                            onTap: { onChapterTap(chapter) },
                            onRemove: { character.appearsInChapters.removeAll { $0.id == chapter.id } }
                        )
                    }
                }

                Button {
                    showChapterPicker = true
                } label: {
                    Label("Добавить главу", systemImage: "plus.circle")
                        .font(.subheadline)
                        .foregroundStyle(Color("AccentColor"))
                }
                .buttonStyle(.plain)
                .disabled(availableChapters.isEmpty)
                .popover(isPresented: $showChapterPicker, arrowEdge: .bottom) {
                    ChapterPickerPopover(
                        chapters: availableChapters,
                        onSelect: { chapter in
                            character.appearsInChapters.append(chapter)
                            showChapterPicker = false
                        }
                    )
                }
            }
        }
    }
}

struct ChapterLinkRow: View {
    var chapter: Chapter
    var onTap: () -> Void = { }
    var onRemove: () -> Void

    var body: some View {
        Button { onTap() } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .foregroundStyle(Color("AccentColor").opacity(0.7))
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(chapter.title.isEmpty ? "Без названия" : chapter.title)
                        .font(.subheadline)
                        .foregroundStyle(Color("PrimaryText"))
                    HStack(spacing: 4) {
                        Image(systemName: chapter.status.icon)
                            .font(.caption2)
                        Text(chapter.status.rawValue)
                            .font(.caption)
                    }
                    .foregroundStyle(chapter.status.color)
                }

                Spacer()

                Button {
                    onRemove()
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
        .buttonStyle(.plain)
    }
}

struct ChapterPickerPopover: View {
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

            if chapters.isEmpty {
                Text("Все главы уже добавлены")
                    .font(.subheadline)
                    .foregroundStyle(Color("SecondaryText"))
                    .padding(16)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(chapters, id: \.id) { chapter in
                            Button {
                                onSelect(chapter)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(chapter.title.isEmpty ? "Без названия" : chapter.title)
                                            .font(.body)
                                            .foregroundStyle(Color("PrimaryText"))
                                        Text(chapter.status.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(chapter.status.color)
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
        }
        .frame(minWidth: 240)
    }
}

// MARK: - Chapter Row

private struct ChapterRow: View {
    let chapter: Chapter
    let isSelected: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: chapter.status.icon)
                    .foregroundStyle(isSelected ? Color("AccentColor") : chapter.status.color)
                    .frame(width: 16)
                Text(chapter.title.isEmpty ? "Без названия" : chapter.title)
                    .font(.body)
                    .foregroundStyle(isSelected ? Color("AccentColor") : Color("PrimaryText"))
                Spacer()
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Переименовать", action: onRename)
            Divider()
            Button("Удалить", role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Chapter List

struct ChapterListView: View {
    var project: WritingProject
    @Binding var selectedChapter: Chapter?
    @Environment(\.modelContext) private var modelContext

    @State private var isAdding = false
    @State private var newTitle = ""
    @State private var editingChapter: Chapter? = nil
    @State private var editingTitle = ""

    var sorted: [Chapter] {
        project.chapters.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        chapterList
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { isAdding = true } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color("PrimaryText"))
                    }
                }
            }
            .alert("Новая глава", isPresented: $isAdding) {
                TextField("Название главы", text: $newTitle)
                Button("Создать") { addChapter() }
                Button("Отмена", role: .cancel) { newTitle = "" }
            }
            .alert("Переименовать", isPresented: Binding(
                get: { editingChapter != nil },
                set: { if !$0 { editingChapter = nil } }
            )) {
                TextField("Название", text: $editingTitle)
                Button("Сохранить") {
                    editingChapter?.title = editingTitle
                    try? modelContext.save()
                    editingChapter = nil
                }
                Button("Отмена", role: .cancel) { editingChapter = nil }
            }
    }

    @ViewBuilder
    private var chapterList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(sorted, id: \.id) { chapter in
                    ChapterRow(
                        chapter: chapter,
                        isSelected: selectedChapter?.persistentModelID == chapter.persistentModelID,
                        onSelect: { selectedChapter = chapter },
                        onRename: {
                            editingChapter = chapter
                            editingTitle = chapter.title
                        },
                        onDelete: {
                            if selectedChapter?.id == chapter.id { selectedChapter = nil }
                            modelContext.delete(chapter)
                            try? modelContext.save()
                        }
                    )
                }
            }
        }
        .background(Color("PrimaryAccent"))
        .overlay {
            if project.chapters.isEmpty {
                emptyChaptersView
            }
        }
    }

    @ViewBuilder
    private var emptyChaptersView: some View {
        ZStack {
            Color("PrimaryAccent").ignoresSafeArea()
            VStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 36))
                    .foregroundStyle(Color("SecondaryText").opacity(0.4))
                Text("Глав пока нет")
                    .foregroundStyle(Color("SecondaryText"))
                Text("Нажмите + чтобы добавить первую")
                    .font(.caption)
                    .foregroundStyle(Color("SecondaryText").opacity(0.6))
            }
        }
    }

    private func addChapter() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let chapter = Chapter(title: title, orderIndex: project.chapters.count)
        chapter.project = project
        project.chapters.append(chapter)
        try? modelContext.save()
        selectedChapter = chapter
        newTitle = ""
    }
}

// MARK: - Chapter Editor

struct ChapterEditorView: View {
    @Bindable var chapter: Chapter
    @Environment(\.modelContext) private var modelContext
    @State private var showPanel = false
    @State private var selectedPanelTab: PanelTab = .characters

    enum PanelTab: String, CaseIterable {
        case characters = "Персонажи"
        case locations  = "Локации"
        case timeline   = "Таймлайн"
        case brief      = "Краткое"

        var icon: String {
            switch self {
            case .characters: return "person.2"
            case .locations:  return "mappin.and.ellipse"
            case .timeline:   return "calendar.day.timeline.left"
            case .brief:      return "doc.plaintext"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Редактор + боковая панель ─────────────────────────
            HStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if chapter.text.isEmpty {
                        Text("Начните писать...")
                            .foregroundStyle(Color("SecondaryText").opacity(0.6))
                            .font(.system(size: 17, design: .serif))
                            .padding(.top, 16)
                            .padding(.leading, 36)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $chapter.text)
                        .font(.system(size: 17, design: .serif))
                        .padding(.horizontal, 30)
                        .scrollContentBackground(.hidden)
                }
                .background(Color("Editor"))

                // ── Боковая панель ────────────────────────────────
                if showPanel {
                    Rectangle()
                        .fill(Color("Border"))
                        .frame(width: 0.5)
                    ChapterSidePanel(chapter: chapter, selectedTab: $selectedPanelTab)
                        .frame(width: 280)
                        .transition(.move(edge: .trailing))
                }
            }
        }
        .background(Color("Editor"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showPanel.toggle()
                    }
                } label: {
                    Image(systemName: showPanel ? "sidebar.right" : "sidebar.right")
                        .symbolVariant(showPanel ? .fill : .none)
                        .foregroundStyle(Color("PrimaryText"))
                }
            }
        }
        .onChange(of: chapter.text) { _, _ in
            chapter.updatedAt = Date()
            try? modelContext.save()
        }
    }
}

// MARK: - Chapter Side Panel

struct ChapterSidePanel: View {
    var chapter: Chapter
    @Binding var selectedTab: ChapterEditorView.PanelTab

    var project: WritingProject? { chapter.project }

    var body: some View {
        VStack(spacing: 0) {
            // Таб-пикер
            Picker("", selection: $selectedTab) {
                ForEach(ChapterEditorView.PanelTab.allCases, id: \.self) { tab in
                    Image(systemName: tab.icon).tag(tab)
                        .font(.system(size: 32))
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Rectangle()
                .fill(Color("Border"))
                .frame(height: 0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .characters:
                            PanelCharactersView(chapter: chapter, project: project)
                    case .locations:
                        PanelLocationsView(project: project)
                    case .timeline:
                        PanelTimelineView(chapter: chapter)
                    case .brief:
                        PanelBriefView(chapter: chapter)
                    }
                }
                .padding(16)
            }
        }
        .background(Color("PrimaryAccent"))
    }
}

// MARK: - Panel: Персонажи

struct PanelCharactersView: View {
    @Bindable var chapter: Chapter
    var project: WritingProject?
    @State private var showPicker = false

    var availableCharacters: [Character] {
        let linked = Set(chapter.characters.map { $0.id })
        return (project?.characters ?? []).filter { !linked.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Персонажи в главе")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color("SecondaryText"))
                .textCase(.uppercase)
                .tracking(0.8)

            if chapter.characters.isEmpty {
                Text("Нет персонажей")
                    .font(.subheadline)
                    .foregroundStyle(Color("SecondaryText").opacity(0.6))
            } else {
                ForEach(chapter.characters, id: \.id) { character in
                    HStack(spacing: 10) {
                        // Круглое фото
                        ZStack {
                            Circle()
                                .fill(Color("AccentColor").opacity(0.15))
                                .frame(width: 34, height: 34)
                            if let data = character.photoData, let img = PlatformImage(data: data) {
                                Image(platformImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 34, height: 34)
                                    .clipShape(Circle())
                            } else {
                                Text(character.name.prefix(1))
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .foregroundStyle(Color("AccentColor"))
                            }
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(character.name)
                                .font(.subheadline)
                            if !character.role.isEmpty {
                                Text(character.role)
                                    .font(.caption)
                                    .foregroundStyle(Color("SecondaryText"))
                            }
                        }

                        Spacer()

                        Button {
                            chapter.characters.removeAll { $0.id == character.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color("SecondaryText"))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Кнопка добавить
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
                VStack(alignment: .leading, spacing: 0) {
                    Text("Выберите персонажа")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 8)
                    Divider()
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(availableCharacters, id: \.id) { character in
                                Button {
                                    chapter.characters.append(character)
                                    showPicker = false
                                } label: {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle()
                                                .fill(Color("AccentColor").opacity(0.15))
                                                .frame(width: 30, height: 30)
                                            if let data = character.photoData, let img = PlatformImage(data: data) {
                                                Image(platformImage: img)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 30, height: 30)
                                                    .clipShape(Circle())
                                            } else {
                                                Text(character.name.prefix(1))
                                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                                    .foregroundStyle(Color("AccentColor"))
                                            }
                                        }
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(character.name)
                                                .font(.body)
                                                .foregroundStyle(Color("PrimaryText"))
                                            if !character.role.isEmpty {
                                                Text(character.role)
                                                    .font(.caption)
                                                    .foregroundStyle(Color("SecondaryText"))
                                            }
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
                .frame(minWidth: 240)
            }
        }
    }
}

// MARK: - Panel: Локации

struct PanelLocationsView: View {
    var project: WritingProject?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Локации персонажей")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color("SecondaryText"))
                .textCase(.uppercase)
                .tracking(0.8)

            let characters = project?.characters ?? []
            let withLocations = characters.filter { !$0.locations.isEmpty }

            if withLocations.isEmpty {
                Text("Локации не заданы")
                    .font(.subheadline)
                    .foregroundStyle(Color("SecondaryText").opacity(0.6))
            } else {
                ForEach(withLocations, id: \.id) { character in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(character.name)
                            .font(.subheadline.weight(.medium))
                        Text(character.locations)
                            .font(.caption)
                            .foregroundStyle(Color("SecondaryText"))
                    }
                    .padding(10)
                    .background(Color("AccentColor").opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

// MARK: - Panel: Таймлайн

struct PanelTimelineView: View {
    var chapter: Chapter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Таймлайн главы")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color("SecondaryText"))
                .textCase(.uppercase)
                .tracking(0.8)

            let events = chapter.timeline.sorted { $0.orderIndex < $1.orderIndex }

            if events.isEmpty {
                Text("Событий нет")
                    .font(.subheadline)
                    .foregroundStyle(Color("SecondaryText").opacity(0.6))
            } else {
                ForEach(events, id: \.id) { event in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: event.type.icon)
                            .foregroundStyle(Color("AccentColor"))
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.subheadline)
                            if !event.date.isEmpty {
                                Text(event.date)
                                    .font(.caption)
                                    .foregroundStyle(Color("SecondaryText"))
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Panel: Краткое

struct PanelBriefView: View {
    var chapter: Chapter

    var wordCount: Int {
        chapter.text.split(separator: " ").count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Статистика
            VStack(alignment: .leading, spacing: 10) {
                Text("Статистика")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color("SecondaryText"))
                    .textCase(.uppercase)
                    .tracking(0.8)

                HStack {
                    Label("\(wordCount) слов", systemImage: "text.word.spacing")
                    Spacer()
                    Label("\(chapter.text.count) симв.", systemImage: "character.cursor.ibeam")
                }
                .font(.subheadline)
                .foregroundStyle(Color("SecondaryText"))
            }

            Divider()

            // Статус
            VStack(alignment: .leading, spacing: 10) {
                Text("Статус")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color("SecondaryText"))
                    .textCase(.uppercase)
                    .tracking(0.8)

                HStack(spacing: 6) {
                    Image(systemName: chapter.status.icon)
                    Text(chapter.status.rawValue)
                }
                .font(.subheadline)
                .foregroundStyle(chapter.status.color)
            }

            Divider()

            // Заметки
            VStack(alignment: .leading, spacing: 10) {
                Text("Заметки")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color("SecondaryText"))
                    .textCase(.uppercase)
                    .tracking(0.8)

                ZStack(alignment: .topLeading) {
                    if chapter.notes.isEmpty {
                        Text("Добавьте заметки к главе...")
                            .foregroundStyle(Color("SecondaryText").opacity(0.6))
                            .font(.caption)
                            .padding(.top, 4)
                            .padding(.leading, 4)
                    }
                    TextEditor(text: Bindable(chapter).notes)
                        .font(.caption)
                        .scrollDisabled(true)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 80)
                }
            }
        }
    }
}

