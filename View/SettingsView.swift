import SwiftUI
import SwiftData

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Заголовок ─────────────────────────────────────────
                HStack {
                    Text("Настройки")
                        .font(.system(.title2, design: .serif, weight: .semibold))
                        .foregroundStyle(Color("PrimaryText"))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color("SecondaryText"))
                            .padding(6)
                            .background(Circle().fill(Color("SecondaryText").opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 20)

                Divider().padding(.horizontal, 28)

                // ── Тема ───────────────────────────────────────────────
                AppearanceSectionView()
                    .padding(.top, 20)

                Divider().padding(.horizontal, 28).padding(.top, 20)

                // ── Редактор ──────────────────────────────────────────
                EditorSectionView()
                    .padding(.top, 20)

                Divider().padding(.horizontal, 28).padding(.top, 20)

                // ── Проекты ───────────────────────────────────────────
                ProjectsSectionView()
                    .padding(.top, 20)

                Divider().padding(.horizontal, 28).padding(.top, 20)

                // ── Журнал аудита ─────────────────────────────────────
                AuditSectionView()
                    .padding(.top, 20)

                Divider().padding(.horizontal, 28).padding(.top, 20)

                // ── Корзина — всегда внизу ────────────────────────────
                TrashSectionView()
                    .padding(.top, 8)
            }
        }
        .background(Color("PrimaryAccent"))
        .environment(\.locale, languageManager.currentLocale)
    }
}

// MARK: - Appearance Section

struct AppearanceSectionView: View {
    @AppStorage("appColorScheme") private var colorSchemeRaw: String = "system"

    private let options: [(id: String, icon: String, label: LocalizedStringKey)] = [
        ("system", "circle.lefthalf.filled", "Системная"),
        ("light",  "sun.max",                "Светлая"),
        ("dark",   "moon",                   "Тёмная"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title: { Text("Оформление") }, icon: { Image(systemName: "paintpalette") })
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color("SecondaryText"))
                .padding(.horizontal, 28)

            HStack(spacing: 10) {
                ForEach(options, id: \.id) { option in
                    Button {
                        colorSchemeRaw = option.id
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: option.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(colorSchemeRaw == option.id
                                    ? Color("AccentColor")
                                    : Color("SecondaryText").opacity(0.5))
                                .frame(height: 24)
                            Text(option.label)
                                .font(.system(size: 12))
                                .foregroundStyle(colorSchemeRaw == option.id
                                    ? Color("AccentColor")
                                    : Color("SecondaryText").opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(colorSchemeRaw == option.id
                                    ? Color("AccentColor").opacity(0.10)
                                    : Color("Editor"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(colorSchemeRaw == option.id
                                            ? Color("AccentColor").opacity(0.4)
                                            : Color.clear, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Editor Section

struct EditorSectionView: View {
    @AppStorage("editorFontSize")    private var fontSize: Double = 17
    @AppStorage("editorPadding")     private var padding: Double = 30
    @AppStorage("timelineDotRadius") private var dotRadius: Double = 7
    @ObservedObject private var languageManager = LanguageManager.shared

    private let languages: [(id: String, label: String)] = [
        ("ru", "Русский"),
        ("en", "English"),
        ("de", "Deutsch"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title: { Text("Редактор") }, icon: { Image(systemName: "pencil.and.outline") })
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color("SecondaryText"))
                .padding(.horizontal, 28)

            VStack(spacing: 0) {
                // Язык интерфейса
                HStack {
                    Text("Язык интерфейса")
                        .font(.body)
                        .foregroundStyle(Color("PrimaryText"))
                    Spacer()
                    Menu {
                        ForEach(languages, id: \.id) { lang in
                            Button {
                                languageManager.setLanguage(lang.id)
                            } label: {
                                HStack {
                                    Text(lang.label)
                                    if languageManager.currentLanguage == lang.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(languages.first(where: { $0.id == languageManager.currentLanguage })?.label ?? "Русский")
                                .font(.system(size: 13))
                                .foregroundStyle(Color("PrimaryText"))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(Color("SecondaryText").opacity(0.6))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color("AccentColor").opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)

                Divider().padding(.leading, 16)

                // Размер шрифта: 11–28
                SettingsStepperRow(
                    label: "Размер шрифта",
                    value: $fontSize,
                    min: 11, max: 28, step: 1,
                    display: { "\(Int($0)) pt" }
                )

                Divider().padding(.leading, 16)

                // Отступ редактора: 0–60 (стандарт 30, максимум 60)
                SettingsStepperRow(
                    label: "Отступ текста",
                    value: $padding,
                    min: 0, max: 60, step: 5,
                    display: { "\(Int($0)) px" }
                )

                Divider().padding(.leading, 16)

                // Радиус точки таймлайна: 1–10
                SettingsStepperRow(
                    label: "Точка таймлайна",
                    value: $dotRadius,
                    min: 1, max: 10, step: 1,
                    display: { "r\(Int($0))" }
                )
            }
            .background(Color("Editor"), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Stepper Row

private struct SettingsStepperRow: View {
    let label: LocalizedStringKey
    @Binding var value: Double
    let min: Double
    let max: Double
    let step: Double
    let display: (Double) -> String

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundStyle(Color("PrimaryText"))
            Spacer()
            HStack(spacing: 0) {
                Button {
                    if value - step >= min { value -= step }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(value <= min ? Color("SecondaryText").opacity(0.3) : Color("AccentColor"))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(value <= min)

                Text(display(value))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color("PrimaryText"))
                    .frame(minWidth: 42)
                    .multilineTextAlignment(.center)

                Button {
                    if value + step <= max { value += step }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(value >= max ? Color("SecondaryText").opacity(0.3) : Color("AccentColor"))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(value >= max)
            }
            .background(Color("AccentColor").opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

// MARK: - Audit Section

struct AuditSectionView: View {
    @Query(sort: \ChapterSnapshot.createdAt, order: .reverse) private var snapshots: [ChapterSnapshot]
    @State private var showAll = false

    private var previewSnapshots: [ChapterSnapshot] { Array(snapshots.prefix(5)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title: { Text("Журнал аудита") }, icon: { Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90") })
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color("SecondaryText"))
                .padding(.horizontal, 28)

            Text("Снимки текста глав создаются автоматически раз в 30 минут во время редактирования.")
                .font(.caption)
                .foregroundStyle(Color("SecondaryText").opacity(0.6))
                .padding(.horizontal, 28)

            if snapshots.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            .font(.system(size: 28))
                            .foregroundStyle(Color("SecondaryText").opacity(0.3))
                        Text("Снимков пока нет")
                            .font(.subheadline)
                            .foregroundStyle(Color("SecondaryText").opacity(0.5))
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(previewSnapshots) { snapshot in
                        AuditSnapshotRow(snapshot: snapshot)
                        if snapshot.id != previewSnapshots.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }

                    if snapshots.count > 5 {
                        Divider()
                        Button {
                            showAll = true
                        } label: {
                            HStack {
                                Spacer()
                                HStack(spacing: 6) {
                                    Text("Ещё \(snapshots.count - 5) снимков")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color("SecondaryText").opacity(0.6))
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color("SecondaryText").opacity(0.4))
                                }
                                Spacer()
                            }
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color("Editor"), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 28)
            }
        }
        .padding(.bottom, 4)
        .sheet(isPresented: $showAll) {
            AuditFullListView(snapshots: Array(snapshots.prefix(50)))
        }
    }
}

// MARK: - Audit Snapshot Row

private struct AuditSnapshotRow: View {
    let snapshot: ChapterSnapshot

    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ru")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: snapshot.createdAt, relativeTo: Date())
    }

    private var wordCount: Int {
        snapshot.content.split(separator: " ").count
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color("AccentColor").opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: "doc.text")
                    .font(.system(size: 13))
                    .foregroundStyle(Color("AccentColor").opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.chapterTitle.isEmpty ? "Без названия" : snapshot.chapterTitle)
                    .font(.body)
                    .foregroundStyle(Color("PrimaryText"))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(wordCount) слов")
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryText").opacity(0.6))
                    Text("·")
                        .foregroundStyle(Color("SecondaryText").opacity(0.4))
                    Text(timeAgo)
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryText").opacity(0.6))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

// MARK: - Audit Full List

struct AuditFullListView: View {
    let snapshots: [ChapterSnapshot]
    @Environment(\.dismiss) private var dismiss
    @State private var selected: ChapterSnapshot? = nil

    var body: some View {
        ZStack {
            Color("PrimaryAccent").ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Журнал аудита")
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(Color("PrimaryText"))
                    Spacer()
                    Button("Закрыть") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color("SecondaryText"))
                }
                .padding(24)
                Divider()
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(snapshots) { snapshot in
                            Button { selected = snapshot } label: {
                                AuditSnapshotRow(snapshot: snapshot)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if snapshot.id != snapshots.last?.id {
                                Divider().padding(.leading, 56).padding(.horizontal, 28)
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(minWidth: 460, minHeight: 400)
        .sheet(item: $selected) { snapshot in
            AuditSnapshotDetailView(snapshot: snapshot)
        }
    }
}

// MARK: - Audit Snapshot Detail

struct AuditSnapshotDetailView: View {
    let snapshot: ChapterSnapshot
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color("PrimaryAccent").ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.chapterTitle.isEmpty ? "Без названия" : snapshot.chapterTitle)
                            .font(.system(.title3, design: .serif, weight: .semibold))
                            .foregroundStyle(Color("PrimaryText"))
                        Text(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(Color("SecondaryText"))
                    }
                    Spacer()
                    Button("Закрыть") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color("SecondaryText"))
                }
                .padding(24)
                Divider()
                ScrollView {
                    Text(snapshot.content.isEmpty ? "Текст отсутствует" : snapshot.content)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Color("PrimaryText"))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                }
                Divider()
                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryText").opacity(0.5))
                    Text("Выделите текст и скопируйте — это снимок только для просмотра.")
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryText").opacity(0.5))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
        .frame(minWidth: 460, minHeight: 360)
    }
}

// MARK: - Projects Section

struct ProjectsSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WritingProject.createdAt, order: .reverse) private var projects: [WritingProject]

    @State private var projectToDelete: WritingProject? = nil
    @State private var projectToRename: WritingProject? = nil
    @State private var renameText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title: { Text("Проекты") }, icon: { Image(systemName: "folder") })
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color("SecondaryText"))
                .padding(.horizontal, 28)

            if projects.isEmpty {
                HStack {
                    Spacer()
                    Text("Проектов нет")
                        .font(.subheadline)
                        .foregroundStyle(Color("SecondaryText").opacity(0.5))
                        .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(projects) { project in
                        ProjectSettingsRow(
                            project: project,
                            onRename: {
                                renameText = project.title
                                projectToRename = project
                            },
                            onDelete: {
                                projectToDelete = project
                            }
                        )
                        if project.id != projects.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .background(Color("Editor"), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 28)
            }
        }
        .padding(.bottom, 4)
        .popover(isPresented: Binding(
            get: { projectToRename != nil },
            set: { if !$0 { projectToRename = nil } }
        )) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Переименовать проект")
                    .font(.headline)
                    .foregroundStyle(Color("PrimaryText"))
                TextField("Название", text: $renameText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color("AccentColor").opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                    .onSubmit { applyRename() }
                HStack {
                    Button("Отмена") { projectToRename = nil }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color("SecondaryText"))
                    Spacer()
                    Button("Сохранить") { applyRename() }
                        .buttonStyle(.borderedProminent)
                        .disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(18)
            .frame(width: 280)
        }
        .alert("Удалить проект?", isPresented: Binding(
            get: { projectToDelete != nil },
            set: { if !$0 { projectToDelete = nil } }
        )) {
            Button("Удалить", role: .destructive) {
                if let p = projectToDelete {
                    modelContext.delete(p)
                    try? modelContext.save()
                    projectToDelete = nil
                }
            }
            Button("Отмена", role: .cancel) { projectToDelete = nil }
        } message: {
            Text("«\(projectToDelete?.title ?? "")» и все его данные будут удалены без возможности восстановления.")
        }
    }

    private func applyRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let p = projectToRename else { return }
        p.title = trimmed
        try? modelContext.save()
        projectToRename = nil
    }
}

// MARK: - Project Settings Row

private struct ProjectSettingsRow: View {
    let project: WritingProject
    let onRename: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: project.type.icon)
                .font(.system(size: 13))
                .foregroundStyle(Color("AccentColor").opacity(0.7))
                .frame(width: 20)

            Text(project.title.isEmpty ? "Без названия" : project.title)
                .font(.body)
                .foregroundStyle(Color("PrimaryText"))
                .lineLimit(1)

            Spacer()

            Text(LocalizedStringKey(project.type.rawValue.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces) ?? project.type.rawValue))
                .font(.caption)
                .foregroundStyle(Color("SecondaryText").opacity(0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isHovered ? Color("AccentColor").opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            Button {
                onRename()
            } label: {
                Label(title: { Text("Переименовать") }, icon: { Image(systemName: "pencil") })
            }

            Divider()

            if project.type == .book || project.type == .visualNovel {
                Menu {
                    Button {
                        ExportService.exportAsDOCX(project)
                    } label: {
                        Label(title: { Text("DOCX") }, icon: { Image(systemName: "doc.richtext") })
                    }
                    Button {
                        ExportService.exportAsTXT(project)
                    } label: {
                        Label(title: { Text("TXT") }, icon: { Image(systemName: "doc.plaintext") })
                    }
                    Button {
                        ExportService.exportAsImpulse(project)
                    } label: {
                        Label(title: { Text("ZIP") }, icon: { Image(systemName: "archivebox") })
                    }
                } label: {
                    Label(title: { Text("Экспортировать") }, icon: { Image(systemName: "arrow.up.forward.square") })
                }
            } else if project.type == .screenplay {
                Menu {
                    Button {
                        ExportService.exportAsDOCX(project)
                    } label: {
                        Label(title: { Text("DOCX") }, icon: { Image(systemName: "doc.richtext") })
                    }
                    Button {
                        ExportService.exportAsTXT(project)
                    } label: {
                        Label(title: { Text("TXT") }, icon: { Image(systemName: "doc.plaintext") })
                    }
                    Button {
                        ExportService.exportAsImpulse(project)
                    } label: {
                        Label(title: { Text("ZIP") }, icon: { Image(systemName: "archivebox") })
                    }
                    Button {
                        ExportService.exportAsFountain(project)
                    } label: {
                        Label(title: { Text("Fountain") }, icon: { Image(systemName: "text.alignleft") })
                    }
                } label: {
                    Label(title: { Text("Экспортировать") }, icon: { Image(systemName: "arrow.up.forward.square") })
                }
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(title: { Text("Удалить проект") }, icon: { Image(systemName: "trash") })
            }
        }
    }
}

// MARK: - Trash Section

struct TrashSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrashItem.deletedAt, order: .reverse) private var trashItems: [TrashItem]

    @State private var selectedItem: TrashItem? = nil
    @State private var itemToDelete: TrashItem? = nil
    @State private var showDeleteAllAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Заголовок секции ─────────────────────────────────────
            HStack {
                Label(title: { Text("Корзина") }, icon: { Image(systemName: "trash") })
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color("SecondaryText"))

                Spacer()

                if !trashItems.isEmpty {
                    Button("Очистить всё") {
                        showDeleteAllAlert = true
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Color.red.opacity(0.7))
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 28)

            Text("Объекты хранятся 2 месяца, затем удаляются автоматически. Восстановление не поддерживается — вы можете скопировать нужные данные.")
                .font(.caption)
                .foregroundStyle(Color("SecondaryText").opacity(0.6))
                .padding(.horizontal, 28)

            if trashItems.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 28))
                            .foregroundStyle(Color("SecondaryText").opacity(0.3))
                        Text("Корзина пуста")
                            .font(.subheadline)
                            .foregroundStyle(Color("SecondaryText").opacity(0.5))
                    }
                    .padding(.vertical, 32)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(trashItems) { item in
                        TrashItemRow(item: item) {
                            selectedItem = item
                        } onDelete: {
                            itemToDelete = item
                        }

                        if item.id != trashItems.last?.id {
                            Divider().padding(.leading, 56).padding(.horizontal, 28)
                        }
                    }
                }
                .background(Color("Editor"), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 28)
            }
        }
        .padding(.bottom, 28)
        .sheet(item: $selectedItem) { item in
            TrashItemDetailView(item: item)
        }
        .alert("Удалить навсегда?", isPresented: Binding(
            get: { itemToDelete != nil },
            set: { if !$0 { itemToDelete = nil } }
        )) {
            Button("Удалить", role: .destructive) {
                if let item = itemToDelete {
                    modelContext.delete(item)
                    itemToDelete = nil
                }
            }
            Button("Отмена", role: .cancel) { itemToDelete = nil }
        } message: {
            Text("«\(itemToDelete?.title ?? "")» будет удалён без возможности восстановления.")
        }
        .alert("Очистить корзину?", isPresented: $showDeleteAllAlert) {
            Button("Очистить", role: .destructive) {
                for item in trashItems { modelContext.delete(item) }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Все \(trashItems.count) объектов будут удалены навсегда.")
        }
    }
}

// MARK: - Trash Item Row

struct TrashItemRow: View {
    let item: TrashItem
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var daysLeft: Int {
        let diff = Calendar.current.dateComponents([.day], from: Date(), to: item.expiresAt)
        return max(diff.day ?? 0, 0)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Иконка типа
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color("AccentColor").opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: item.itemType.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(Color("AccentColor").opacity(0.7))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title.isEmpty ? "Без названия" : item.title)
                        .font(.body)
                        .foregroundStyle(Color("PrimaryText"))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(LocalizedStringKey(item.itemType.rawValue))
                            .font(.caption)
                            .foregroundStyle(Color("SecondaryText").opacity(0.6))

                        Text("·")
                            .foregroundStyle(Color("SecondaryText").opacity(0.4))

                        Text(item.projectTitle)
                            .font(.caption)
                            .foregroundStyle(Color("SecondaryText").opacity(0.6))
                            .lineLimit(1)

                        Spacer()

                        Text(daysLeft == 0 ? "Скоро удалится" : "Ещё \(daysLeft) дн.")
                            .font(.caption2)
                            .foregroundStyle(daysLeft < 7 ? Color.red.opacity(0.6) : Color("SecondaryText").opacity(0.4))
                    }
                }

                // Кнопка удаления
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color("SecondaryText").opacity(0.5))
                        .padding(5)
                        .background(Circle().fill(Color("SecondaryText").opacity(0.08)))
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isHovered ? Color("AccentColor").opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Trash Item Detail (просмотр снимка)

struct TrashItemDetailView: View {
    let item: TrashItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color("PrimaryAccent").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // ── Шапка ────────────────────────────────────────────
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title.isEmpty ? "Без названия" : item.title)
                            .font(.system(.title3, design: .serif, weight: .semibold))
                            .foregroundStyle(Color("PrimaryText"))
                        Text("\(item.itemType.rawValue) · \(item.projectTitle)")
                            .font(.caption)
                            .foregroundStyle(Color("SecondaryText"))
                    }
                    Spacer()
                    Button("Закрыть") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color("SecondaryText"))
                }
                .padding(24)

                Divider()

                // ── Снимок данных ────────────────────────────────────
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Данные объекта")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color("SecondaryText"))
                            .tracking(0.8)
                            .padding(.bottom, 10)

                        Text(item.snapshot.isEmpty ? "Данные отсутствуют" : item.snapshot)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Color("PrimaryText"))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color("Editor"), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(24)
                }

                Divider()

                // ── Подсказка ─────────────────────────────────────────
                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryText").opacity(0.5))
                    Text("Выделите нужный текст и скопируйте — восстановление объекта в проект недоступно.")
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryText").opacity(0.5))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
        .frame(minWidth: 460, minHeight: 360)
    }
}
