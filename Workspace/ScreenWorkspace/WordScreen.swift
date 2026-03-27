import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Scene Row

private struct SceneRow: View {
    let scene: ScreenScene
    let isSelected: Bool
    var isDragTarget: Bool = false
    var showLabels: Bool = false
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 0) {
                if showLabels {
                    let labelColor = RowLabelColor(rawValue: scene.colorLabel)
                    Circle()
                        .fill(labelColor?.color ?? Color.clear)
                        .frame(width: 8, height: 8)
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
                    Image(systemName: scene.status.icon)
                        .foregroundStyle(isSelected ? Color("AccentColor") : scene.status.color)
                        .frame(width: 16)
                    Text(scene.title.isEmpty ? "Без названия" : scene.title)
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
                Button { scene.colorLabel = "" } label: {
                    Label("Убрать метку" as LocalizedStringKey, systemImage: scene.colorLabel.isEmpty ? "checkmark" : "circle")
                }
                Divider()
                ForEach(RowLabelColor.allCases, id: \.self) { lc in
                    Button { scene.colorLabel = lc.rawValue } label: {
                        Label(lc.title, systemImage: scene.colorLabel == lc.rawValue ? "checkmark.circle.fill" : "circle.fill")
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

private struct SceneDropDelegate: DropDelegate {
    let targetScene: ScreenScene
    let scenes: [ScreenScene]
    @Binding var draggingID: UUID?
    @Binding var dropTargetID: UUID?
    let onReorder: (UUID, UUID) -> Void

    func dropEntered(info: DropInfo) { dropTargetID = targetScene.id }
    func dropExited(info: DropInfo) { if dropTargetID == targetScene.id { dropTargetID = nil } }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        defer { draggingID = nil; dropTargetID = nil }
        guard let fromID = draggingID else { return false }
        onReorder(fromID, targetScene.id)
        return true
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggingID != nil && draggingID != targetScene.id
    }
}

// MARK: - Scene List

struct SceneListView: View {
    var project: WritingProject
    @Binding var selectedScene: ScreenScene?
    @AppStorage("showSceneLabels") private var showLabels: Bool = false
    @AppStorage(ChapterListFilter.statusesKey) private var statusesRaw: String = ""
    @AppStorage(ChapterListFilter.colorsKey)   private var colorsRaw: String = ""
    @Environment(\.modelContext) private var modelContext

    @State private var isAdding = false
    @State private var newTitle = ""
    @State private var editingScene: ScreenScene? = nil
    @State private var editingTitle = ""
    @State private var draggingSceneID: UUID? = nil
    @State private var dropTargetID: UUID? = nil

    var sorted: [ScreenScene] {
        let all = (project.scenes ?? []).sorted { $0.orderIndex < $1.orderIndex }
        let statuses = ChapterListFilter.activeStatuses()
        let colors   = ChapterListFilter.activeColors()
        guard !statuses.isEmpty || !colors.isEmpty else { return all }
        return all.filter { scene in
            let statusMatch = statuses.isEmpty || statuses.contains(scene.status)
            let colorMatch: Bool = {
                guard !colors.isEmpty else { return true }
                guard let lc = RowLabelColor(rawValue: scene.colorLabel) else { return false }
                return colors.contains(lc)
            }()
            return statusMatch && colorMatch
        }
    }

    var body: some View {
        sceneList
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { isAdding = true } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color("PrimaryText"))
                    }
                    .popover(isPresented: $isAdding) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Новая сцена")
                                .font(.headline)
                                .foregroundStyle(Color("PrimaryText"))
                            TextField("Название сцены", text: $newTitle)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .frame(width: 220)
                                .glassEffect(in: .rect(cornerRadius: 8))
                                .onSubmit {
                                    if !newTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                                        addScene(); isAdding = false
                                    }
                                }
                            HStack {
                                Button("Отмена") { newTitle = ""; isAdding = false }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(Color("SecondaryText"))
                                Spacer()
                                Button("Создать") { addScene(); isAdding = false }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                        .padding(18)
                    }
                }
            }
            .popover(isPresented: Binding(
                get: { editingScene != nil },
                set: { if !$0 { editingScene = nil } }
            )) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Переименовать сцену")
                        .font(.headline)
                        .foregroundStyle(Color("PrimaryText"))
                    TextField("Название", text: $editingTitle)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(width: 220)
                        .glassEffect(in: .rect(cornerRadius: 8))
                    HStack {
                        Button("Отмена") { editingScene = nil }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color("SecondaryText"))
                        Spacer()
                        Button("Сохранить") {
                            editingScene?.title = editingTitle
                            try? modelContext.save()
                            editingScene = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(editingTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(18)
            }
    }

    @ViewBuilder
    private var sceneList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(sorted, id: \.id) { scene in
                    SceneRow(
                        scene: scene,
                        isSelected: selectedScene?.persistentModelID == scene.persistentModelID,
                        isDragTarget: dropTargetID == scene.id,
                        showLabels: showLabels,
                        onSelect: { selectedScene = scene },
                        onRename: {
                            editingScene = scene
                            editingTitle = scene.title
                        },
                        onDelete: {
                            if selectedScene?.id == scene.id { selectedScene = nil }
                            let trash = TrashItem(
                                type: .chapter,
                                projectTitle: project.title,
                                title: scene.title.isEmpty ? "Без названия" : scene.title,
                                snapshot: sceneSnapshot(scene)
                            )
                            modelContext.insert(trash)
                            modelContext.delete(scene)
                            try? modelContext.save()
                        }
                    )
                    .onDrag {
                        draggingSceneID = scene.id
                        return NSItemProvider(object: scene.id.uuidString as NSString)
                    }
                    .onDrop(of: [.plainText], delegate: SceneDropDelegate(
                        targetScene: scene,
                        scenes: sorted,
                        draggingID: $draggingSceneID,
                        dropTargetID: $dropTargetID,
                        onReorder: { fromID, toID in
                            reorderScenes(from: fromID, to: toID)
                        }
                    ))
                }
            }
        }
        .background(Color("PrimaryAccent"))
        .overlay {
            if (project.scenes ?? []).isEmpty {
                ZStack {
                    Color("PrimaryAccent").ignoresSafeArea()
                    VStack(spacing: 8) {
                        Image(systemName: "film")
                            .font(.system(size: 36))
                            .foregroundStyle(Color("SecondaryText").opacity(0.4))
                        Text("Сцен пока нет")
                            .foregroundStyle(Color("SecondaryText"))
                        Text("Нажмите + чтобы добавить первую")
                            .font(.caption)
                            .foregroundStyle(Color("SecondaryText").opacity(0.6))
                    }
                }
            }
        }
    }

    private func reorderScenes(from fromID: UUID, to toID: UUID) {
        var reordered = sorted
        guard
            let fromIdx = reordered.firstIndex(where: { $0.id == fromID }),
            let toIdx   = reordered.firstIndex(where: { $0.id == toID }),
            fromIdx != toIdx
        else { return }
        let item = reordered.remove(at: fromIdx)
        reordered.insert(item, at: toIdx)
        for (newIndex, scene) in reordered.enumerated() {
            scene.orderIndex = newIndex
        }
        try? modelContext.save()
    }

    private func addScene() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let scene = ScreenScene(title: title, orderIndex: (project.scenes ?? []).count)
        scene.project = project
        project.scenes = (project.scenes ?? []) + [scene]
        try? modelContext.save()
        selectedScene = scene
        newTitle = ""
    }
}

// MARK: - Scene Editor (no right sidebar)

struct SceneEditorView: View {
    @Bindable var scene: ScreenScene
    @Environment(\.modelContext) private var modelContext
    @AppStorage("editorFontSize") private var fontSize: Double = 17
    @AppStorage("editorPadding")  private var editorPadding: Double = 30

    // Локальный индекс активной вариации (синхронизируется с моделью)
    @State private var activeIndex: Int = 0

    private var variations: [SceneVariation] { scene.variations }

    private var currentText: Binding<String> {
        Binding(
            get: {
                let vars = scene.variations
                guard activeIndex < vars.count else { return "" }
                return vars[activeIndex].text
            },
            set: { newValue in
                var vars = scene.variations
                guard activeIndex < vars.count else { return }
                vars[activeIndex].text = newValue
                scene.variations = vars
            }
        )
    }

    private var currentRTF: Binding<Data> {
        Binding(
            get: {
                let vars = scene.variations
                guard activeIndex < vars.count else { return Data() }
                return vars[activeIndex].textData
            },
            set: { newValue in
                var vars = scene.variations
                guard activeIndex < vars.count else { return }
                vars[activeIndex].textData = newValue
                scene.variations = vars
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                if currentText.wrappedValue.isEmpty && currentRTF.wrappedValue.isEmpty {
                    Text("Начните писать...")
                        .foregroundStyle(Color("SecondaryText").opacity(0.6))
                        .font(.system(size: fontSize, design: .serif))
                        .padding(.top, 16)
                        .padding(.leading, editorPadding + 6)
                        .allowsHitTesting(false)
                }
                RichTextEditor(
                    rtfData: currentRTF,
                    plainText: currentText,
                    fontSize: fontSize,
                    horizontalPadding: editorPadding,
                    topPadding: 16
                )
            }
            .background(Color("Editor"))
        }
        .background(Color("Editor"))
        .toolbar {
            ToolbarItem(placement: .principal) {
                SceneVariationTabBar(
                    variations: variations,
                    activeIndex: $activeIndex,
                    onAdd: addVariation,
                    onDelete: deleteVariation
                )
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    FocusWindowManager.shared.open(
                        value: FocusEditorValue(kind: .scene, id: scene.id),
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
        .onChange(of: currentText.wrappedValue) { _, _ in
            scene.updatedAt = Date()
            try? modelContext.save()
        }
        .onChange(of: scene.persistentModelID) { _, _ in
            // При смене сцены восстанавливаем последний активный индекс
            activeIndex = min(scene.activeVariationIndex, max(0, scene.variations.count - 1))
        }
        .onAppear {
            activeIndex = min(scene.activeVariationIndex, max(0, scene.variations.count - 1))
        }
    }

    private func addVariation() {
        var vars = scene.variations
        guard vars.count < 6 else { return }
        let newTitle = "Variation \(vars.count + 1)"
        vars.append(SceneVariation(title: newTitle))
        scene.variations = vars
        activeIndex = vars.count - 1
        scene.activeVariationIndex = activeIndex
        try? modelContext.save()
    }

    private func deleteVariation(at index: Int) {
        var vars = scene.variations
        guard vars.count > 1, index < vars.count else { return }
        vars.remove(at: index)
        // Переименовываем вариации для последовательности
        for i in vars.indices {
            vars[i].title = "Variation \(i + 1)"
        }
        scene.variations = vars
        activeIndex = min(activeIndex, vars.count - 1)
        scene.activeVariationIndex = activeIndex
        try? modelContext.save()
    }
}

// MARK: - Variation Tab Bar

struct SceneVariationTabBar: View {
    let variations: [SceneVariation]
    @Binding var activeIndex: Int
    let onAdd: () -> Void
    let onDelete: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(variations.enumerated()), id: \.element.id) { index, variation in
                variationTab(index: index, title: variation.title)
            }

            if variations.count < 6 {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color("SecondaryText"))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Добавить вариацию")
            }
        }
    }

    @ViewBuilder
    private func variationTab(index: Int, title: String) -> some View {
        let isActive = index == activeIndex

        HStack(spacing: 3) {
            Button(action: { activeIndex = index }) {
                Text(title)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? Color("AccentColor") : Color("SecondaryText"))
                    .lineLimit(1)
            }
            .buttonStyle(.plain)

            if variations.count > 1 {
                Button(action: { onDelete(index) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(isActive ? Color("AccentColor").opacity(0.8) : Color("SecondaryText").opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Удалить вариацию")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? Color("AccentColor").opacity(0.12) : Color.clear)
                .padding(.horizontal, 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isActive ? Color("AccentColor").opacity(0.3) : Color.clear, lineWidth: 1)
                .padding(.horizontal, 6)
        )
    }
}

// MARK: - Fullscreen Scene Editor

struct FullscreenSceneEditor: View {
    @Bindable var scene: ScreenScene
    var onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage("editorFontSize") private var fontSize: Double = 17
    @AppStorage("editorFocusPadding") private var focusPadding: Double = 40
    @State private var activeIndex: Int = 0
    @State private var showControls = true
    @State private var hideTask: Task<Void, Never>? = nil

    private var variations: [SceneVariation] { scene.variations }

    private var currentText: Binding<String> {
        Binding(
            get: {
                let vars = scene.variations
                guard activeIndex < vars.count else { return "" }
                return vars[activeIndex].text
            },
            set: { newValue in
                var vars = scene.variations
                guard activeIndex < vars.count else { return }
                vars[activeIndex].text = newValue
                scene.variations = vars
            }
        )
    }

    private var currentRTF: Binding<Data> {
        Binding(
            get: {
                let vars = scene.variations
                guard activeIndex < vars.count else { return Data() }
                return vars[activeIndex].textData
            },
            set: { newValue in
                var vars = scene.variations
                guard activeIndex < vars.count else { return }
                vars[activeIndex].textData = newValue
                scene.variations = vars
            }
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color("Editor").ignoresSafeArea()

            // ── Текстовый редактор ────────────────────────────────
            ZStack(alignment: .topLeading) {
                if currentText.wrappedValue.isEmpty && currentRTF.wrappedValue.isEmpty {
                    Text("Начните писать...")
                        .foregroundStyle(Color("SecondaryText").opacity(0.4))
                        .font(.system(size: fontSize, design: .serif))
                        .padding(.top, 16)
                        .padding(.leading, focusPadding + 6)
                        .allowsHitTesting(false)
                }
                RichTextEditor(
                    rtfData: currentRTF,
                    plainText: currentText,
                    fontSize: fontSize,
                    horizontalPadding: focusPadding,
                    topPadding: 16
                )
            }
            .background(Color("Editor"))

            // ── Панель управления ─────────────────────────────────
            if showControls {
                VStack(spacing: 0) {
                    HStack {
                        Text(scene.title.isEmpty ? "Без названия" : scene.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color("SecondaryText").opacity(0.6))
                        Spacer()
                        let wordCount = currentText.wrappedValue.split(separator: " ").count
                        Text("\(wordCount) сл.")
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(Color("SecondaryText").opacity(0.5))
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

                    // Табы вариаций
                    SceneVariationTabBar(
                        variations: variations,
                        activeIndex: $activeIndex,
                        onAdd: {
                            var vars = scene.variations
                            guard vars.count < 6 else { return }
                            vars.append(SceneVariation(title: "Variation \(vars.count + 1)"))
                            scene.variations = vars
                            activeIndex = vars.count - 1
                        },
                        onDelete: { index in
                            var vars = scene.variations
                            guard vars.count > 1, index < vars.count else { return }
                            vars.remove(at: index)
                            for i in vars.indices { vars[i].title = "Variation \(i + 1)" }
                            scene.variations = vars
                            activeIndex = min(activeIndex, vars.count - 1)
                        }
                    )
                    .padding(.vertical, 6)
                    .padding(.horizontal, 20)
                    .background(.ultraThinMaterial)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            activeIndex = min(scene.activeVariationIndex, max(0, scene.variations.count - 1))
            resetHideTimer()
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
        .onChange(of: currentText.wrappedValue) { _, _ in
            scene.updatedAt = Date()
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

// MARK: - Trash Snapshot

private func sceneSnapshot(_ scene: ScreenScene) -> String {
    var lines: [String] = []
    lines.append("Название: \(scene.title)")
    lines.append("Статус: \(scene.status.rawValue)")
    if !scene.notes.isEmpty { lines.append("\n— Заметки —\n\(scene.notes)") }
    if !scene.text.isEmpty  { lines.append("\n— Текст —\n\(scene.text)") }
    return lines.joined(separator: "\n")
}
