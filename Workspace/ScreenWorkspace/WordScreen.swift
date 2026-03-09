import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Scene Row

private struct SceneRow: View {
    let scene: Scene
    let isSelected: Bool
    var isDragTarget: Bool = false
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: scene.status.icon)
                    .foregroundStyle(isSelected ? Color("AccentColor") : scene.status.color)
                    .frame(width: 16)
                Text(scene.title.isEmpty ? "Без названия" : scene.title)
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
            Button("Удалить", role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Drop Delegate

private struct SceneDropDelegate: DropDelegate {
    let targetScene: Scene
    let scenes: [Scene]
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
    @Binding var selectedScene: Scene?
    @Environment(\.modelContext) private var modelContext

    @State private var isAdding = false
    @State private var newTitle = ""
    @State private var editingScene: Scene? = nil
    @State private var editingTitle = ""
    @State private var draggingSceneID: UUID? = nil
    @State private var dropTargetID: UUID? = nil

    var sorted: [Scene] {
        project.scenes.sorted { $0.orderIndex < $1.orderIndex }
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
            if project.scenes.isEmpty {
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
        let scene = Scene(title: title, orderIndex: project.scenes.count)
        scene.project = project
        project.scenes.append(scene)
        try? modelContext.save()
        selectedScene = scene
        newTitle = ""
    }
}

// MARK: - Scene Editor (no right sidebar)

struct SceneEditorView: View {
    @Bindable var scene: Scene
    @Environment(\.modelContext) private var modelContext
    @AppStorage("editorFontSize") private var fontSize: Double = 17
    @AppStorage("editorPadding")  private var editorPadding: Double = 30

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                if scene.text.isEmpty {
                    Text("Начните писать...")
                        .foregroundStyle(Color("SecondaryText").opacity(0.6))
                        .font(.system(size: fontSize, design: .serif))
                        .padding(.top, 16)
                        .padding(.leading, editorPadding + 6)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $scene.text)
                    .font(.system(size: fontSize, design: .serif))
                    .padding(.horizontal, editorPadding)
                    .scrollContentBackground(.hidden)
                    .padding(.top, 16)
            }
            .background(Color("Editor"))
        }
        .background(Color("Editor"))
        .onChange(of: scene.text) { _, _ in
            scene.updatedAt = Date()
            try? modelContext.save()
        }
    }
}

// MARK: - Trash Snapshot

private func sceneSnapshot(_ scene: Scene) -> String {
    var lines: [String] = []
    lines.append("Название: \(scene.title)")
    lines.append("Статус: \(scene.status.rawValue)")
    if !scene.notes.isEmpty { lines.append("\n— Заметки —\n\(scene.notes)") }
    if !scene.text.isEmpty  { lines.append("\n— Текст —\n\(scene.text)") }
    return lines.joined(separator: "\n")
}
