import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Role List

struct RoleListView: View {
    var project: WritingProject
    @Binding var selectedRole: ScreenRole?
    @Environment(\.modelContext) private var modelContext

    @State private var isAddingRole = false
    @State private var newRoleName = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(project.screenRoles, id: \.persistentModelID) { role in
                    let isSelected = selectedRole?.persistentModelID == role.persistentModelID
                    Button { selectedRole = role } label: {
                        RoleRowView(role: role, isSelected: isSelected)
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
                Button { isAddingRole = true } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color("PrimaryText"))
                }
                .popover(isPresented: $isAddingRole) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Новая роль")
                            .font(.headline)
                            .foregroundStyle(Color("PrimaryText"))
                        TextField("Имя персонажа", text: $newRoleName)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(width: 220)
                            .glassEffect(in: .rect(cornerRadius: 8))
                            .onSubmit {
                                if !newRoleName.trimmingCharacters(in: .whitespaces).isEmpty {
                                    addRole(); isAddingRole = false
                                }
                            }
                        HStack {
                            Button("Отмена") { newRoleName = ""; isAddingRole = false }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color("SecondaryText"))
                            Spacer()
                            Button("Создать") { addRole(); isAddingRole = false }
                                .buttonStyle(.borderedProminent)
                                .disabled(newRoleName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .padding(18)
                }
            }
        }
        .overlay {
            if project.screenRoles.isEmpty {
                ZStack {
                    Color("PrimaryAccent").ignoresSafeArea()
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 36))
                            .foregroundStyle(Color("SecondaryText").opacity(0.4))
                        Text("Ролей пока нет")
                            .foregroundStyle(Color("SecondaryText"))
                        Text("Нажмите «+» чтобы добавить первую")
                            .font(.caption)
                            .foregroundStyle(Color("SecondaryText").opacity(0.6))
                    }
                }
            }
        }
    }

    private func addRole() {
        let name = newRoleName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let role = ScreenRole(name: name)
        role.project = project
        project.screenRoles.append(role)
        try? modelContext.save()
        selectedRole = role
        newRoleName = ""
    }
}

// MARK: - Role Row

struct RoleRowView: View {
    var role: ScreenRole
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color("AccentColor").opacity(0.15))
                    .frame(width: 36, height: 36)

                if let data = role.photoData, let img = PlatformImage(data: data) {
                    Image(platformImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Text(role.name.prefix(1))
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color("AccentColor"))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(role.name)
                    .font(.body)
                    .foregroundStyle(isSelected ? Color("AccentColor") : Color("PrimaryText"))
                if !role.role.isEmpty {
                    Text(role.role)
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryText"))
                }
            }
        }
    }
}

// MARK: - Role Card

struct RoleCardView: View {
    @Bindable var role: ScreenRole
    var onSceneTap: (Scene) -> Void = { _ in }
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

                                if let data = role.photoData, let img = PlatformImage(data: data) {
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
                            TextField("Имя персонажа", text: $role.name)
                                .font(.system(.title2, design: .serif, weight: .semibold))
                                .textFieldStyle(.plain)

                            TextField("Роль (главный герой, злодей...)", text: $role.role)
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

                    CardSection(icon: "eye", title: "Внешность") {
                        GrowingTextEditor(text: $role.appearance,
                                          placeholder: "Опишите внешность персонажа...")
                    }

                    Rectangle().fill(Color("Border")).frame(height: 0.5)

                    CardSection(icon: "book.closed", title: "Биография") {
                        GrowingTextEditor(text: $role.biography,
                                          placeholder: "История жизни, ключевые события...")
                    }

                    Rectangle().fill(Color("Border")).frame(height: 0.5)

                    CardSection(icon: "bolt", title: "Способности") {
                        GrowingTextEditor(text: $role.abilities,
                                          placeholder: "Навыки, таланты...")
                    }

                    Rectangle().fill(Color("Border")).frame(height: 0.5)

                    CardSection(icon: "theatermasks", title: "Роль в сюжете") {
                        GrowingTextEditor(text: $role.plotRole,
                                          placeholder: "Какую функцию выполняет в истории...")
                    }

                    Rectangle().fill(Color("Border")).frame(height: 0.5)

                    SceneAppearancesSection(role: role, onSceneTap: onSceneTap)
                }
                .padding(24)
            }
        }
        .background(Color("PrimaryAccent"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Выбрать из Фото", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        openImageFromFinder { data in role.photoData = data }
                    } label: {
                        Label("Выбрать файл...", systemImage: "folder")
                    }

                    if role.photoData != nil {
                        Button(role: .destructive) {
                            role.photoData = nil
                        } label: {
                            Label("Удалить фото", systemImage: "photo.badge.minus")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Удалить роль", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(Color("PrimaryText"))
                }
            }
        }
        .alert("Удалить роль?", isPresented: $showDeleteAlert) {
            Button("Удалить", role: .destructive) { deleteRole() }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Это действие нельзя отменить.")
        }
        .onChange(of: photoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    role.photoData = data
                }
            }
        }
    }

    private func deleteRole() {
        let trash = TrashItem(
            type: .character,
            projectTitle: role.project?.title ?? "",
            title: role.name.isEmpty ? "Без имени" : role.name,
            snapshot: roleSnapshot(role)
        )
        modelContext.insert(trash)
        modelContext.delete(role)
        try? modelContext.save()
    }
}

private func openRoleImageFromFinder(onSelect: @escaping (Data) -> Void) {
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

// MARK: - Scene Appearances Section

struct SceneAppearancesSection: View {
    @Bindable var role: ScreenRole
    var onSceneTap: (Scene) -> Void = { _ in }
    @State private var showScenePicker = false

    var project: WritingProject? { role.project }

    var availableScenes: [Scene] {
        let linked = Set(role.appearsInScenes.map { $0.id })
        return (project?.scenes ?? [])
            .filter { !linked.contains($0.id) }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        CardSection(icon: "film", title: "Появления в сценах") {
            VStack(alignment: .leading, spacing: 8) {

                if role.appearsInScenes.isEmpty {
                    Text("Ни одной сцены не добавлено")
                        .font(.subheadline)
                        .foregroundStyle(Color("SecondaryText").opacity(0.6))
                        .padding(.vertical, 4)
                } else {
                    ForEach(
                        role.appearsInScenes.sorted { $0.orderIndex < $1.orderIndex },
                        id: \.id
                    ) { scene in
                        SceneLinkRow(
                            scene: scene,
                            onTap: { onSceneTap(scene) },
                            onRemove: {
                                role.appearsInScenes.removeAll { $0.id == scene.id }
                                scene.roles.removeAll { $0.id == role.id }
                            }
                        )
                    }
                }

                Button {
                    showScenePicker = true
                } label: {
                    Label("Добавить сцену", systemImage: "plus.circle")
                        .font(.subheadline)
                        .foregroundStyle(Color("AccentColor"))
                }
                .buttonStyle(.plain)
                .disabled(availableScenes.isEmpty)
                .popover(isPresented: $showScenePicker, arrowEdge: .bottom) {
                    ScenePickerPopover(
                        scenes: availableScenes,
                        onSelect: { scene in
                            role.appearsInScenes.append(scene)
                            if !scene.roles.contains(where: { $0.id == role.id }) {
                                scene.roles.append(role)
                            }
                            showScenePicker = false
                        }
                    )
                }
            }
        }
    }
}

struct SceneLinkRow: View {
    var scene: Scene
    var onTap: () -> Void = { }
    var onRemove: () -> Void

    var body: some View {
        Button { onTap() } label: {
            HStack(spacing: 10) {
                Image(systemName: scene.status.icon)
                    .foregroundStyle(Color("AccentColor").opacity(0.7))
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(scene.title.isEmpty ? "Без названия" : scene.title)
                        .font(.subheadline)
                        .foregroundStyle(Color("PrimaryText"))
                    HStack(spacing: 4) {
                        Image(systemName: scene.status.icon)
                            .font(.caption2)
                        Text(scene.status.rawValue)
                            .font(.caption)
                    }
                    .foregroundStyle(scene.status.color)
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

struct ScenePickerPopover: View {
    var scenes: [Scene]
    var onSelect: (Scene) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Выберите сцену")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            Divider()

            if scenes.isEmpty {
                Text("Все сцены уже добавлены")
                    .font(.subheadline)
                    .foregroundStyle(Color("SecondaryText"))
                    .padding(16)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(scenes, id: \.id) { scene in
                            Button {
                                onSelect(scene)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(scene.title.isEmpty ? "Без названия" : scene.title)
                                            .font(.body)
                                            .foregroundStyle(Color("PrimaryText"))
                                        Text(scene.status.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(scene.status.color)
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

// MARK: - Trash Snapshot

private func roleSnapshot(_ role: ScreenRole) -> String {
    var lines: [String] = []
    lines.append("Имя: \(role.name)")
    if !role.role.isEmpty { lines.append("Роль: \(role.role)") }
    if !role.biography.isEmpty { lines.append("\n— Биография —\n\(role.biography)") }
    return lines.joined(separator: "\n")
}
