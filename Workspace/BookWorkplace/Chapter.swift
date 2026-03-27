import SwiftUI
import SwiftData
import UniformTypeIdentifiers




// MARK: - Chapter Appearances Section

struct ChapterAppearancesSection: View {
       @State private var searchText: String = ""
    @Bindable var character: Character
    var onChapterTap: (Chapter) -> Void = { _ in }
    @State private var showChapterPicker = false

    var project: WritingProject? { character.project }

    var availableChapters: [Chapter] {
        let linked = Set((character.appearsInChapters ?? []).map { $0.id })
        return (project?.chapters ?? [])
            .filter { !linked.contains($0.id) }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        CardSection(icon: "text.book.closed", title: "Появления в главах") {
            VStack(alignment: .leading, spacing: 8) {

                if (character.appearsInChapters ?? []).isEmpty {
                    Text("Ни одной главы не добавлено")
                        .font(.subheadline)
                        .foregroundStyle(Color("SecondaryText").opacity(0.6))
                        .padding(.vertical, 4)
                } else {
                    ForEach(
                        (character.appearsInChapters ?? []).sorted { $0.orderIndex < $1.orderIndex },
                        id: \.id
                    ) { chapter in
                        ChapterLinkRow(
                            chapter: chapter,
                            onTap: { onChapterTap(chapter) },
                            onRemove: {
                                character.appearsInChapters?.removeAll { $0.id == chapter.id }
                                chapter.characters?.removeAll { $0.id == character.id }
                            }
                        )
                    }
                }

                Button {
                    showChapterPicker = true
                } label: {
                    Label(title: { Text("Добавить главу") }, icon: { Image(systemName: "plus.circle") })
                        .font(.subheadline)
                        .foregroundStyle(Color("AccentColor"))
                }
                .buttonStyle(.plain)
                .disabled(availableChapters.isEmpty)
                .popover(isPresented: $showChapterPicker, arrowEdge: .bottom) {
                    ChapterPickerPopover(
                        chapters: availableChapters,
                        onSelect: { chapter in
                            character.appearsInChapters = (character.appearsInChapters ?? []) + [chapter]
                            if !(chapter.characters ?? []).contains(where: { $0.id == character.id }) {
                                chapter.characters = (chapter.characters ?? []) + [character]
                            }
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
                        Text(LocalizedStringKey(chapter.status.rawValue))
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
                                        Text(LocalizedStringKey(chapter.status.rawValue))
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
        .background(Color("PrimaryAccent"))
    }
}

// MARK: - Chapter List Filter

/// Shared filter state stored in AppStorage (comma-separated raw values, empty = no filter)
enum ChapterListFilter {
    static let statusesKey = "chapterFilterStatuses"
    static let colorsKey   = "chapterFilterColors"

    static var isActive: Bool {
        let statuses = UserDefaults.standard.string(forKey: statusesKey) ?? ""
        let colors   = UserDefaults.standard.string(forKey: colorsKey) ?? ""
        return !statuses.isEmpty || !colors.isEmpty
    }

    static func activeStatuses() -> Set<ChapterStatus> {
        let raw = UserDefaults.standard.string(forKey: statusesKey) ?? ""
        return Set(raw.split(separator: ",").compactMap { ChapterStatus(rawValue: String($0)) })
    }

    static func activeColors() -> Set<RowLabelColor> {
        let raw = UserDefaults.standard.string(forKey: colorsKey) ?? ""
        return Set(raw.split(separator: ",").compactMap { RowLabelColor(rawValue: String($0)) })
    }

    static func toggleStatus(_ status: ChapterStatus) {
        var active = activeStatuses()
        if active.contains(status) { active.remove(status) } else { active.insert(status) }
        UserDefaults.standard.set(active.map(\.rawValue).joined(separator: ","), forKey: statusesKey)
    }

    static func toggleColor(_ color: RowLabelColor) {
        var active = activeColors()
        if active.contains(color) { active.remove(color) } else { active.insert(color) }
        UserDefaults.standard.set(active.map(\.rawValue).joined(separator: ","), forKey: colorsKey)
    }

    static func clearAll() {
        UserDefaults.standard.set("", forKey: statusesKey)
        UserDefaults.standard.set("", forKey: colorsKey)
    }
}

// MARK: - Filter Popover

struct ChapterFilterPopover: View {
    @AppStorage(ChapterListFilter.statusesKey) private var statusesRaw: String = ""
    @AppStorage(ChapterListFilter.colorsKey)   private var colorsRaw: String = ""

    private var activeStatuses: Set<ChapterStatus> { ChapterListFilter.activeStatuses() }
    private var activeColors: Set<RowLabelColor>   { ChapterListFilter.activeColors() }
    private var hasFilters: Bool { !statusesRaw.isEmpty || !colorsRaw.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Фильтр")
                    .font(.headline)
                    .foregroundStyle(Color("PrimaryText"))
                Spacer()
                if hasFilters {
                    Button("Сбросить") { ChapterListFilter.clearAll() }
                        .buttonStyle(.plain)
                        .font(.subheadline)
                        .foregroundStyle(Color("AccentColor"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Status section
                    Text("Статус")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("SecondaryText"))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 4)

                    ForEach(ChapterStatus.allCases, id: \.self) { status in
                        let isOn = activeStatuses.contains(status)
                        Button {
                            ChapterListFilter.toggleStatus(status)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: status.icon)
                                    .foregroundStyle(status.color)
                                    .frame(width: 16)
                                Text(LocalizedStringKey(status.rawValue))
                                    .foregroundStyle(Color("PrimaryText"))
                                Spacer()
                                if isOn {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color("AccentColor"))
                                        .font(.system(size: 12, weight: .semibold))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Divider().padding(.top, 4)

                    // Color label section
                    Text("Метка")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("SecondaryText"))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 4)

                    ForEach(RowLabelColor.allCases, id: \.self) { lc in
                        let isOn = activeColors.contains(lc)
                        Button {
                            ChapterListFilter.toggleColor(lc)
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(lc.color)
                                    .frame(width: 12, height: 12)
                                Text(lc.title)
                                    .foregroundStyle(Color("PrimaryText"))
                                Spacer()
                                if isOn {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color("AccentColor"))
                                        .font(.system(size: 12, weight: .semibold))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 360)
        }
        .frame(width: 220)
        .background(Color("PrimaryAccent"))
    }
}

// MARK: - Row Label Color

enum RowLabelColor: String, CaseIterable {
    case red    = "red"
    case orange = "orange"
    case yellow = "yellow"
    case green  = "green"
    case blue   = "blue"
    case purple = "purple"
    case gray   = "gray"

    var title: LocalizedStringKey {
        switch self {
        case .red:    return "Красный"
        case .orange: return "Оранжевый"
        case .yellow: return "Жёлтый"
        case .green:  return "Зелёный"
        case .blue:   return "Синий"
        case .purple: return "Лиловый"
        case .gray:   return "Серый"
        }
    }

    var color: Color {
        switch self {
        case .red:    return Color(red: 0.95, green: 0.30, blue: 0.30)
        case .orange: return Color(red: 0.98, green: 0.60, blue: 0.20)
        case .yellow: return Color(red: 0.98, green: 0.85, blue: 0.20)
        case .green:  return Color(red: 0.30, green: 0.80, blue: 0.45)
        case .blue:   return Color(red: 0.25, green: 0.55, blue: 0.95)
        case .purple: return Color(red: 0.65, green: 0.35, blue: 0.90)
        case .gray:   return Color(red: 0.60, green: 0.60, blue: 0.65)
        }
    }
}

// MARK: - Chapter Row

private struct ChapterRow: View {
    let chapter: Chapter
    let isSelected: Bool
    var isDragTarget: Bool = false
    var showLabels: Bool = false
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 0) {
                // Полоска: жёлтая цитата (без галочки) или цветной круг (с галочкой)
                if showLabels {
                    let labelColor = RowLabelColor(rawValue: chapter.colorLabel)
                    Circle()
                        .fill(labelColor?.color ?? Color.clear)
                        .frame(width: 13, height: 13)
                        .padding(.leading, 10)
                        .padding(.trailing, 6)
                        .padding(.vertical, 4)
                } else {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.yellow.opacity(0.8))
                        .frame(width: 3)
                        .padding(.vertical, 4)
                        .padding(.leading, 8)
                }
                HStack(spacing: 8) {
                    Image(systemName: chapter.status.icon)
                        .foregroundStyle(isSelected ? Color("AccentColor") : chapter.status.color)
                        .frame(width: 16)
                    Text(chapter.title.isEmpty ? "Без названия" : chapter.title)
                        .font(.body)
                        .foregroundStyle(isSelected ? Color("AccentColor") : Color("PrimaryText"))
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
            }
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
        .overlay(alignment: .top) {
            if isDragTarget {
                Rectangle()
                    .fill(Color("AccentColor"))
                    .frame(height: 2)
                    .padding(.horizontal, 8)
            }
        }
        .contextMenu {
            Button("Переименовать", action: onRename)
            Divider()
            Menu {
                Button { chapter.colorLabel = "" } label: {
                    Label("Убрать метку" as LocalizedStringKey, systemImage: chapter.colorLabel.isEmpty ? "checkmark" : "circle")
                }
                Divider()
                ForEach(RowLabelColor.allCases, id: \.self) { lc in
                    Button { chapter.colorLabel = lc.rawValue } label: {
                        Label(lc.title, systemImage: chapter.colorLabel == lc.rawValue ? "checkmark.circle.fill" : "circle.fill")
                    }
                }
            } label: {
                Text("Метка" as LocalizedStringKey)
            }
            Divider()
            Button("Удалить", role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Drop Delegate

private struct ChapterDropDelegate: DropDelegate {
    let targetChapter: Chapter
    let chapters: [Chapter]
    @Binding var draggingID: UUID?
    @Binding var dropTargetID: UUID?
    let onReorder: (UUID, UUID) -> Void

    func dropEntered(info: DropInfo) {
        dropTargetID = targetChapter.id
    }

    func dropExited(info: DropInfo) {
        if dropTargetID == targetChapter.id {
            dropTargetID = nil
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            draggingID = nil
            dropTargetID = nil
        }
        guard let fromID = draggingID else { return false }
        onReorder(fromID, targetChapter.id)
        return true
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggingID != nil && draggingID != targetChapter.id
    }
}

// MARK: - Chapter List

struct ChapterListView: View {
    var project: WritingProject
    @Binding var selectedChapter: Chapter?
    @AppStorage("showChapterLabels") private var showLabels: Bool = false
    @AppStorage(ChapterListFilter.statusesKey) private var statusesRaw: String = ""
    @AppStorage(ChapterListFilter.colorsKey)   private var colorsRaw: String = ""
    @Environment(\.modelContext) private var modelContext

    @State private var isAdding = false
    @State private var newTitle = ""
    @State private var editingChapter: Chapter? = nil
    @State private var editingTitle = ""
    @State private var draggingChapterID: UUID? = nil
    @State private var dropTargetID: UUID? = nil

    var sorted: [Chapter] {
        let all = (project.chapters ?? []).sorted { $0.orderIndex < $1.orderIndex }
        let statuses = ChapterListFilter.activeStatuses()
        let colors   = ChapterListFilter.activeColors()
        guard !statuses.isEmpty || !colors.isEmpty else { return all }
        return all.filter { chapter in
            let statusMatch = statuses.isEmpty || statuses.contains(chapter.status)
            let colorMatch: Bool = {
                guard !colors.isEmpty else { return true }
                guard let lc = RowLabelColor(rawValue: chapter.colorLabel) else { return false }
                return colors.contains(lc)
            }()
            return statusMatch && colorMatch
        }
    }

    var body: some View {
        chapterList
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { isAdding = true } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color("PrimaryText"))
                    }
                    .popover(isPresented: $isAdding) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Новая глава")
                                .font(.headline)
                                .foregroundStyle(Color("PrimaryText"))
                            TextField("Название главы", text: $newTitle)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .frame(width: 220)
                                .glassEffect(in: .rect(cornerRadius: 8))
                                .onSubmit {
                                    if !newTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                                        addChapter(); isAdding = false
                                    }
                                }
                            HStack {
                                Button("Отмена") { newTitle = ""; isAdding = false }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(Color("SecondaryText"))
                                Spacer()
                                Button("Создать") { addChapter(); isAdding = false }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                        .padding(18)
                    }
                }
            }
            .popover(isPresented: Binding(
                get: { editingChapter != nil },
                set: { if !$0 { editingChapter = nil } }
            )) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Переименовать главу")
                        .font(.headline)
                        .foregroundStyle(Color("PrimaryText"))
                    TextField("Название", text: $editingTitle)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(width: 220)
                        .glassEffect(in: .rect(cornerRadius: 8))
                    HStack {
                        Button("Отмена") { editingChapter = nil }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color("SecondaryText"))
                        Spacer()
                        Button("Сохранить") {
                            editingChapter?.title = editingTitle
                            try? modelContext.save()
                            editingChapter = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(editingTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(18)
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
                        isDragTarget: dropTargetID == chapter.id,
                        showLabels: showLabels,
                        onSelect: { selectedChapter = chapter },
                        onRename: {
                            editingChapter = chapter
                            editingTitle = chapter.title
                        },
                        onDelete: {
                            if selectedChapter?.id == chapter.id { selectedChapter = nil }
                            let trash = TrashItem(
                                type: .chapter,
                                projectTitle: project.title,
                                title: chapter.title.isEmpty ? "Без названия" : chapter.title,
                                snapshot: chapterSnapshot(chapter)
                            )
                            modelContext.insert(trash)
                            modelContext.delete(chapter)
                            try? modelContext.save()
                        }
                    )
                    .onDrag {
                        draggingChapterID = chapter.id
                        return NSItemProvider(object: chapter.id.uuidString as NSString)
                    }
                    .onDrop(of: [.plainText], delegate: ChapterDropDelegate(
                        targetChapter: chapter,
                        chapters: sorted,
                        draggingID: $draggingChapterID,
                        dropTargetID: $dropTargetID,
                        onReorder: { fromID, toID in
                            reorderChapters(from: fromID, to: toID)
                        }
                    ))
                }
            }
        }
        .background(Color("PrimaryAccent"))
        .overlay {
            if (project.chapters ?? []).isEmpty {
                emptyChaptersView
            }
        }
    }

    private func reorderChapters(from fromID: UUID, to toID: UUID) {
        var reordered = sorted
        guard
            let fromIdx = reordered.firstIndex(where: { $0.id == fromID }),
            let toIdx   = reordered.firstIndex(where: { $0.id == toID }),
            fromIdx != toIdx
        else { return }
        let item = reordered.remove(at: fromIdx)
        reordered.insert(item, at: toIdx)
        for (newIndex, chapter) in reordered.enumerated() {
            chapter.orderIndex = newIndex
        }
        try? modelContext.save()
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
        let chapter = Chapter(title: title, orderIndex: (project.chapters ?? []).count)
        chapter.project = project
        project.chapters = (project.chapters ?? []) + [chapter]
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
    @AppStorage("editorFontSize") private var fontSize: Double = 17
    @AppStorage("editorPadding")  private var editorPadding: Double = 30
    /// Время последнего сохранённого снапшота для этой главы
    @State private var lastSnapshotDate: Date = .distantPast

    enum PanelTab: String, CaseIterable {
        case characters = "Персонажи"
        case locations  = "Локации"
        case tags       = "Теги"
        case brief      = "Краткое"

        var icon: String {
            switch self {
            case .characters: return "person.2"
            case .locations:  return "mappin.and.ellipse"
            case .tags:       return "tag"
            case .brief:      return "doc.plaintext"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Редактор + боковая панель ─────────────────────────
            HStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if chapter.text.isEmpty && chapter.textData.isEmpty {
                        Text("Начните писать...")
                            .foregroundStyle(Color("SecondaryText").opacity(0.6))
                            .font(.system(size: fontSize, design: .serif))
                            .padding(.top, 16)
                            .padding(.leading, editorPadding + 6)
                            .allowsHitTesting(false)
                    }
                    RichTextEditor(
                        rtfData: Bindable(chapter).textData,
                        plainText: Bindable(chapter).text,
                        fontSize: fontSize,
                        horizontalPadding: editorPadding,
                        topPadding: 16
                    )
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
            ToolbarItem(placement: .primaryAction) {
                Button {
                    FocusWindowManager.shared.open(
                        value: FocusEditorValue(kind: .chapter, id: chapter.id),
                        modelContainer: modelContext.container
                    )
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .foregroundStyle(Color("PrimaryText"))
                }
                .help("Открыть в окне фокуса (⌘⇧F)")
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }
        .onChange(of: chapter.text) { _, newText in
            chapter.updatedAt = Date()
            try? modelContext.save()
            saveSnapshotIfNeeded(text: newText)
        }
        .onAppear {
            // Загружаем дату последнего снапшота при открытии главы
            let id = chapter.id
            let descriptor = FetchDescriptor<ChapterSnapshot>(
                predicate: #Predicate { $0.chapterID == id },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            if let latest = try? modelContext.fetch(descriptor).first {
                lastSnapshotDate = latest.createdAt
            }
        }
    }

    private func saveSnapshotIfNeeded(text: String) {
        guard !text.isEmpty else { return }
        let now = Date()
        guard now.timeIntervalSince(lastSnapshotDate) >= 30 * 60 else { return }
        let snapshot = ChapterSnapshot(
            chapterID: chapter.id,
            chapterTitle: chapter.title,
            content: text
        )
        modelContext.insert(snapshot)
        try? modelContext.save()
        lastSnapshotDate = now

        // Оставляем не более 50 снапшотов на главу
        let id = chapter.id
        let allDescriptor = FetchDescriptor<ChapterSnapshot>(
            predicate: #Predicate { $0.chapterID == id },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        if let all = try? modelContext.fetch(allDescriptor), all.count > 50 {
            for old in all.dropFirst(50) { modelContext.delete(old) }
            try? modelContext.save()
        }
    }
}

// MARK: - Fullscreen Chapter Editor

struct FullscreenChapterEditor: View {
    @Bindable var chapter: Chapter
    var onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage("editorFontSize") private var fontSize: Double = 17
    @AppStorage("editorFocusPadding") private var focusPadding: Double = 40
    @State private var showControls = true
    @State private var hideTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack(alignment: .top) {
            Color("Editor").ignoresSafeArea()

            // ── Текстовый редактор ────────────────────────────────
            ZStack(alignment: .topLeading) {
                if chapter.text.isEmpty && chapter.textData.isEmpty {
                    Text("Начните писать...")
                        .foregroundStyle(Color("SecondaryText").opacity(0.4))
                        .font(.system(size: fontSize, design: .serif))
                        .padding(.top, 16)
                        .padding(.leading, focusPadding + 6)
                        .allowsHitTesting(false)
                }
                RichTextEditor(
                    rtfData: Bindable(chapter).textData,
                    plainText: Bindable(chapter).text,
                    fontSize: fontSize,
                    horizontalPadding: focusPadding,
                    topPadding: 16
                )
            }
            .background(Color("Editor"))
            .onHover { _ in resetHideTimer() }

            // ── Панель управления (исчезает при неактивности) ─────
            if showControls {
                HStack {
                    // Название главы
                    Text(chapter.title.isEmpty ? "Без названия" : chapter.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color("SecondaryText").opacity(0.6))
                    Spacer()
                    // Счётчик слов
                    let wordCount = chapter.text.split(separator: " ").count
                    Text("\(wordCount) сл.")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(Color("SecondaryText").opacity(0.5))
                    // Кнопка выхода
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 14))
                            .foregroundStyle(Color("SecondaryText").opacity(0.6))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Выйти из полноэкранного режима (Esc)")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { resetHideTimer() }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
        .onChange(of: chapter.text) { _, _ in
            chapter.updatedAt = Date()
            try? modelContext.save()
            resetHideTimer()
        }
        .onContinuousHover { phase in
            if case .active = phase { resetHideTimer() }
        }
    }

    private func resetHideTimer() {
        hideTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) { showControls = true }
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) { showControls = false }
            }
        }
    }
}

// MARK: - Chapter Side Panel

struct ChapterSidePanel: View {
    @Bindable var chapter: Chapter
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
                        PanelLocationsView(chapter: chapter, project: project)
                    case .tags:
                        PanelTagsView(chapter: chapter)
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
        let linked = Set((chapter.characters ?? []).map { $0.id })
        return (project?.characters ?? []).filter { !linked.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Персонажи в главе")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color("SecondaryText"))
                .textCase(.uppercase)
                .tracking(0.8)

            if (chapter.characters ?? []).isEmpty {
                Text("Нет персонажей")
                    .font(.subheadline)
                    .foregroundStyle(Color("SecondaryText").opacity(0.6))
            } else {
                ForEach(chapter.characters ?? [], id: \.id) { character in
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
                            chapter.characters?.removeAll { $0.id == character.id }
                            character.appearsInChapters?.removeAll { $0.id == chapter.id }
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
                Label(title: { Text("Добавить персонажа") }, icon: { Image(systemName: "plus.circle") })
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
                                    chapter.characters = (chapter.characters ?? []) + [character]
                                    if !(character.appearsInChapters ?? []).contains(where: { $0.id == chapter.id }) {
                                        character.appearsInChapters = (character.appearsInChapters ?? []) + [chapter]
                                    }
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
    @Bindable var chapter: Chapter
    var project: WritingProject?
    @State private var showPicker = false

    private var allLocations: [WorldLocation] {
        project?.worldBuilding?.locations ?? []
    }

    private var linkedLocations: [WorldLocation] {
        allLocations.filter { ($0.chapters ?? []).contains(where: { $0.id == chapter.id }) }
    }

    private var availableLocations: [WorldLocation] {
        let linked = Set(linkedLocations.map { $0.id })
        return allLocations.filter { !linked.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Локации главы")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color("SecondaryText"))
                .textCase(.uppercase)
                .tracking(0.8)

            if linkedLocations.isEmpty {
                Text("Локаций нет")
                    .font(.subheadline)
                    .foregroundStyle(Color("SecondaryText").opacity(0.6))
            } else {
                ForEach(linkedLocations, id: \.id) { location in
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(Color("AccentColor").opacity(0.7))
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(location.name.isEmpty ? "Без названия" : location.name)
                                .font(.subheadline)
                            if !location.type.isEmpty {
                                Text(location.type)
                                    .font(.caption)
                                    .foregroundStyle(Color("SecondaryText"))
                            }
                        }
                        Spacer()
                        Button {
                            location.chapters?.removeAll { $0.id == chapter.id }
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
                Label(title: { Text("Добавить локацию") }, icon: { Image(systemName: "plus.circle") })
                    .font(.subheadline)
                    .foregroundStyle(Color("AccentColor"))
            }
            .buttonStyle(.plain)
            .disabled(availableLocations.isEmpty)
            .popover(isPresented: $showPicker, arrowEdge: .bottom) {
                LocationPickerPopover(locations: availableLocations) { location in
                    if !(location.chapters ?? []).contains(where: { $0.id == chapter.id }) {
                        location.chapters = (location.chapters ?? []) + [chapter]
                    }
                    showPicker = false
                }
            }
        }
    }
}

struct LocationPickerPopover: View {
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
                        Button { onSelect(location) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(location.name.isEmpty ? "Без названия" : location.name)
                                        .font(.body)
                                        .foregroundStyle(Color("PrimaryText"))
                                    if !location.type.isEmpty {
                                        Text(location.type)
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
        .background(Color("PrimaryAccent"))
    }
}

// MARK: - Panel: Теги

private let allChapterTagKeys: [String] = [
    "tag.intrigue", "tag.conflict", "tag.character_reveal", "tag.backstory", "tag.mystery",
    "tag.tension", "tag.plot_twist", "tag.discovery", "tag.journey", "tag.encounter",
    "tag.parting", "tag.danger", "tag.battle", "tag.investigation", "tag.romance",
    "tag.betrayal", "tag.alliance", "tag.trial", "tag.victory", "tag.defeat",
    "tag.planning", "tag.escape", "tag.chase", "tag.revelation", "tag.inner_conflict",
    "tag.relationship_development", "tag.sacrifice", "tag.hope", "tag.despair", "tag.climax"
]

struct PanelTagsView: View {
    @Bindable var chapter: Chapter
    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("tag.section.title")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color("SecondaryText"))
                .textCase(.uppercase)
                .tracking(0.8)

            // Chip grid для выбранных тегов
            if chapter.tags.isEmpty {
                Text("tag.empty")
                    .font(.subheadline)
                    .foregroundStyle(Color("SecondaryText").opacity(0.6))
            } else {
                TagChipGrid(tags: chapter.tags) { tag in
                    chapter.tags.removeAll { $0 == tag }
                }
            }

            Button {
                showPicker = true
            } label: {
                Label(LocalizedStringKey("tag.add"), systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundStyle(Color("AccentColor"))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPicker, arrowEdge: .bottom) {
                TagPickerPopover(
                    allTagKeys: allChapterTagKeys,
                    selectedTags: chapter.tags
                ) { key in
                    if !chapter.tags.contains(key) {
                        chapter.tags.append(key)
                    } else {
                        chapter.tags.removeAll { $0 == key }
                    }
                }
            }
        }
    }
}

// Отображает выбранные теги в виде переносимой сетки чипов
struct TagChipGrid: View {
    var tags: [String]     // хранятся как ключи, напр. "tag.intrigue"
    var onRemove: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let rows = tags.chunked(into: 2)
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 6) {
                    ForEach(rows[rowIndex], id: \.self) { key in
                        TagChip(tagKey: key) { onRemove(key) }
                    }
                }
            }
        }
    }
}

struct TagChip: View {
    var tagKey: String     // ключ локализации
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(LocalizedStringKey(tagKey))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color("AccentColor"))
            Button { onRemove() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color("AccentColor").opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color("AccentColor").opacity(0.12), in: Capsule())
    }
}

struct TagPickerPopover: View {
    var allTagKeys: [String]   // ключи локализации
    var selectedTags: [String] // тоже ключи
    var onToggle: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("tag.picker.title")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(allTagKeys, id: \.self) { key in
                        let isSelected = selectedTags.contains(key)
                        Button { onToggle(key) } label: {
                            HStack {
                                Text(LocalizedStringKey(key))
                                    .font(.body)
                                    .foregroundStyle(Color("PrimaryText"))
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color("AccentColor"))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .background(isSelected ? Color("AccentColor").opacity(0.07) : Color.clear)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 320)
        }
        .frame(minWidth: 220)
        .background(Color("PrimaryAccent"))
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Panel: Краткое

struct PanelBriefView: View {
    @Bindable var chapter: Chapter
    @State private var showStatusPicker = false

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
                    Label(title: { Text("\(wordCount) слов") }, icon: { Image(systemName: "text.word.spacing") })
                    Spacer()
                    Label(title: { Text("\(chapter.text.count) симв.") }, icon: { Image(systemName: "character.cursor.ibeam") })
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

                Button {
                    showStatusPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: chapter.status.icon)
                        Text(LocalizedStringKey(chapter.status.rawValue))
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(Color("SecondaryText").opacity(0.5))
                    }
                    .font(.subheadline)
                    .foregroundStyle(chapter.status.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(chapter.status.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showStatusPicker, arrowEdge: .bottom) {
                    StatusPickerPopover(selected: chapter.status) { newStatus in
                        chapter.status = newStatus
                        showStatusPicker = false
                    }
                }
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

// MARK: - Status Picker Popover

struct StatusPickerPopover: View {
    var selected: ChapterStatus
    var onSelect: (ChapterStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Статус главы")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            Divider()

            VStack(spacing: 0) {
                ForEach(ChapterStatus.allCases, id: \.self) { status in
                    Button {
                        onSelect(status)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: status.icon)
                                .foregroundStyle(status.color)
                                .frame(width: 18)
                            Text(LocalizedStringKey(status.rawValue))
                                .font(.body)
                                .foregroundStyle(Color("PrimaryText"))
                            Spacer()
                            if status == selected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color("AccentColor"))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(status == selected ? Color("AccentColor").opacity(0.07) : Color.clear)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
        .frame(minWidth: 220)
        .background(Color("PrimaryAccent"))
    }
}

// MARK: - Trash Snapshot

private func chapterSnapshot(_ chapter: Chapter) -> String {
    var lines: [String] = []
    lines.append("Название: \(chapter.title)")
    lines.append("Статус: \(chapter.status.rawValue)")
    if !chapter.tags.isEmpty {
        lines.append("Теги: \(chapter.tags.joined(separator: ", "))")
    }
    if !chapter.notes.isEmpty {
        lines.append("\n— Заметки —\n\(chapter.notes)")
    }
    if !chapter.text.isEmpty {
        lines.append("\n— Текст —\n\(chapter.text)")
    }
    return lines.joined(separator: "\n")
}

