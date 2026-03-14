import SwiftUI

// MARK: - Scene Info Sheet (⌘I)

struct SceneInfoView: View {
    @Bindable var scene: ScreenScene
    var project: WritingProject

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: InfoTab = .info
    @State private var selectedVariationIndex: Int = 0
    @State private var showStatusPicker = false
    @State private var showRolePicker = false

    enum InfoTab: String, CaseIterable, Identifiable {
        case info        = "Информация"
        case description = "Описание"
        case locations   = "Локации"
        case roles       = "Роли"
        case timing      = "Хронометраж"
        case notes       = "Заметки"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .info:        return "info.circle"
            case .description: return "text.alignleft"
            case .locations:   return "mappin"
            case .roles:       return "person.2"
            case .timing:      return "clock"
            case .notes:       return "note.text"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Заголовок ────────────────────────────────────────────────
            HStack(alignment: .center, spacing: 10) {
                Text(scene.title.isEmpty ? "Без названия" : scene.title)
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .foregroundStyle(Color("PrimaryText"))
                    .lineLimit(1)
                    .truncationMode(.tail)

                // Статус-бейдж
                Button {
                    showStatusPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(scene.status.color)
                            .frame(width: 6, height: 6)
                        Text(LocalizedStringKey(scene.status.rawValue))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(scene.status.color)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(scene.status.color.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showStatusPicker, arrowEdge: .bottom) {
                    SceneStatusPickerPopover(currentStatus: scene.status) { newStatus in
                        scene.status = newStatus
                        showStatusPicker = false
                    }
                }

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color("SecondaryText"))
                        .padding(6)
                        .background(Circle().fill(Color("SecondaryText").opacity(0.12)))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            // ── Вкладки ──────────────────────────────────────────────────
            Picker("", selection: $selectedTab) {
                ForEach(InfoTab.allCases) { tab in
                    Image(systemName: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 28)
            .padding(.vertical, 10)

            Divider()

            // ── Содержимое ───────────────────────────────────────────────
            Group {
                switch selectedTab {
                case .info:
                    InfoTabView(scene: scene, selectedVariationIndex: $selectedVariationIndex)
                case .description:
                    TextTabView(text: $scene.sceneDescription, placeholder: "Описание сцены...")
                case .locations:
                    TextTabView(text: $scene.sceneLocations, placeholder: "Локации сцены...")
                case .roles:
                    RolesTabView(scene: scene, project: project, showRolePicker: $showRolePicker)
                case .timing:
                    TextTabView(text: $scene.timing, placeholder: "Хронометраж сцены...")
                case .notes:
                    TextTabView(text: $scene.notes, placeholder: "Заметки к сцене...")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color("PrimaryAccent"))
        .onAppear {
            selectedVariationIndex = min(scene.activeVariationIndex,
                                         max(0, scene.variations.count - 1))
        }
    }
}

// MARK: - Вкладка "Информация"

private struct InfoTabView: View {
    @Bindable var scene: ScreenScene
    @Binding var selectedVariationIndex: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                let vars = scene.variations

                // Переключатель вариаций
                if vars.count > 1 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Вариация")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color("SecondaryText").opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(0.6)

                        Picker("", selection: $selectedVariationIndex) {
                            ForEach(Array(vars.enumerated()), id: \.element.id) { i, v in
                                Text(v.title).tag(i)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)

                    Divider().padding(.horizontal, 28)
                }

                // Статистика выбранной вариации
                let clampedIndex = min(selectedVariationIndex, vars.count - 1)
                if vars.indices.contains(clampedIndex) {
                    let v = vars[clampedIndex]
                    let wordCount = v.text.split(separator: " ").filter { !$0.isEmpty }.count
                    let charCount = v.text.count

                    VStack(alignment: .leading, spacing: 10) {
                        Text(vars.count > 1 ? "Статистика вариации" : "Статистика")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color("SecondaryText").opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(0.6)

                        HStack(spacing: 32) {
                            StatItem(label: "Слов", value: "\(wordCount)")
                            StatItem(label: "Символов", value: "\(charCount)")
                            if vars.count > 1 {
                                StatItem(label: "Вариация", value: "\(clampedIndex + 1) / \(vars.count)")
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                }

                // Общая статистика (если несколько вариаций)
                if vars.count > 1 {
                    Divider().padding(.horizontal, 28)

                    let totalWords = vars.reduce(0) { $0 + $1.text.split(separator: " ").filter { !$0.isEmpty }.count }
                    let totalChars = vars.reduce(0) { $0 + $1.text.count }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Итого по сцене")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color("SecondaryText").opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(0.6)

                        HStack(spacing: 32) {
                            StatItem(label: "Вариаций", value: "\(vars.count)")
                            StatItem(label: "Слов всего", value: "\(totalWords)")
                            StatItem(label: "Символов всего", value: "\(totalChars)")
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                }

                Spacer(minLength: 24)
            }
        }
    }
}

// MARK: - Вкладка текстового редактора

private struct TextTabView: View {
    @Binding var text: String
    let placeholder: LocalizedStringKey

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.body)
                .foregroundStyle(Color("PrimaryText"))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

            if text.isEmpty {
                Text(placeholder)
                    .font(.body)
                    .foregroundStyle(Color("SecondaryText").opacity(0.4))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Вкладка "Роли"

private struct RolesTabView: View {
    @Bindable var scene: ScreenScene
    var project: WritingProject
    @Binding var showRolePicker: Bool

    var availableRoles: [ScreenRole] {
        let linked = Set(scene.roles.map { $0.id })
        return project.screenRoles
            .filter { !linked.contains($0.id) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Кнопка добавления
                HStack {
                    Button {
                        showRolePicker = true
                    } label: {
                        Label {
                            Text("Добавить роль")
                                .font(.subheadline)
                        } icon: {
                            Image(systemName: "plus.circle")
                        }
                        .foregroundStyle(Color("AccentColor"))
                    }
                    .buttonStyle(.plain)
                    .disabled(availableRoles.isEmpty)
                    .popover(isPresented: $showRolePicker, arrowEdge: .bottom) {
                        RolePickerPopover(roles: availableRoles) { role in
                            scene.roles.append(role)
                            if !role.appearsInScenes.contains(where: { $0.id == scene.id }) {
                                role.appearsInScenes.append(scene)
                            }
                            showRolePicker = false
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)

                Divider().padding(.horizontal, 28)

                if scene.roles.isEmpty {
                    Text("Нет ролей")
                        .font(.body)
                        .foregroundStyle(Color("SecondaryText").opacity(0.4))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(scene.roles) { role in
                            HStack(spacing: 10) {
                                Image(systemName: "person")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color("SecondaryText").opacity(0.5))
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(role.name.isEmpty ? "Без имени" : role.name)
                                        .font(.body)
                                        .foregroundStyle(Color("PrimaryText"))
                                    if !role.role.isEmpty {
                                        Text(role.role)
                                            .font(.caption)
                                            .foregroundStyle(Color("SecondaryText").opacity(0.6))
                                    }
                                }

                                Spacer()

                                Button {
                                    scene.roles.removeAll { $0.id == role.id }
                                    role.appearsInScenes.removeAll { $0.id == scene.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color("SecondaryText").opacity(0.4))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 10)

                            Divider().padding(.horizontal, 28)
                        }
                    }
                }

                Spacer(minLength: 24)
            }
        }
    }
}

// MARK: - Popover выбора роли

private struct RolePickerPopover: View {
    let roles: [ScreenRole]
    let onSelect: (ScreenRole) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Добавить роль")
                .font(.headline)
                .foregroundStyle(Color("PrimaryText"))
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            Divider()

            if roles.isEmpty {
                Text("Нет доступных ролей")
                    .font(.body)
                    .foregroundStyle(Color("SecondaryText"))
                    .padding(16)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(roles) { role in
                            Button {
                                onSelect(role)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(role.name.isEmpty ? "Без имени" : role.name)
                                            .font(.body)
                                            .foregroundStyle(Color("PrimaryText"))
                                        if !role.role.isEmpty {
                                            Text(role.role)
                                                .font(.caption)
                                                .foregroundStyle(Color("SecondaryText").opacity(0.6))
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
        }
        .frame(minWidth: 240)
        .background(Color("PrimaryAccent"))
    }
}

// MARK: - Popover выбора статуса

private struct SceneStatusPickerPopover: View {
    let currentStatus: ChapterStatus
    let onSelect: (ChapterStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Статус")
                .font(.headline)
                .foregroundStyle(Color("PrimaryText"))
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
                            Circle()
                                .fill(status.color)
                                .frame(width: 8, height: 8)
                            Text(LocalizedStringKey(status.rawValue))
                                .font(.body)
                                .foregroundStyle(Color("PrimaryText"))
                            Spacer()
                            if status == currentStatus {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color("AccentColor"))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
        .frame(minWidth: 200)
        .background(Color("PrimaryAccent"))
    }
}

// MARK: - Helpers

private struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(Color("PrimaryText"))
            Text(label)
                .font(.caption)
                .foregroundStyle(Color("SecondaryText").opacity(0.6))
        }
    }
}
