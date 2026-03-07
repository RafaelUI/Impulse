import SwiftUI
import SwiftData

// MARK: - Timeline Workspace

struct TimelineWorkspaceView: View {
    var project: WritingProject
    @Binding var selectedTrack: TimelineTrack?
    @Environment(\.modelContext) private var modelContext

    @State private var isAdding = false
    @State private var newTrackName = ""
    @State private var renamingTrack: TimelineTrack? = nil
    @State private var renamingTitle = ""

    private var sorted: [TimelineTrack] {
        project.timelineTracks.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var sortedChapters: [Chapter] {
        project.chapters.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        HStack(spacing: 0) {
            // ── Левая колонка: список треков ──────────────────────
            trackList
                .frame(width: 220)
                .background(Color("PrimaryAccent"))

            Rectangle()
                .fill(Color("Border"))
                .frame(width: 0.5)

            // ── Правая часть: редактор ─────────────────────────────
            VStack(spacing: 0) {
                // ── Полоса глав ────────────────────────────────────
                ChapterStrip(chapters: sortedChapters)

                Rectangle()
                    .fill(Color("Border"))
                    .frame(height: 0.5)

                // ── Общий редактор всех треков ─────────────────────
                if sorted.isEmpty {
                    ZStack {
                        Color("Editor")
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.day.timeline.left")
                                .font(.system(size: 36))
                                .foregroundStyle(Color("SecondaryText").opacity(0.4))
                            Text("Добавьте трек слева")
                                .font(.body)
                                .foregroundStyle(Color("SecondaryText"))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(sorted, id: \.id) { track in
                                TrackSection(track: track, modelContext: modelContext)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                    .background(Color("Editor"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    // MARK: - Track List

    @ViewBuilder
    private var trackList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Заголовок ─────────────────────────────────────────
            Text("Треки")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color("PrimaryText").opacity(0.4))
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            // ── Список ────────────────────────────────────────────
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(sorted, id: \.id) { track in
                        TrackRow(
                            track: track,
                            onRename: {
                                renamingTrack = track
                                renamingTitle = track.title
                            },
                            onDelete: {
                                modelContext.delete(track)
                                try? modelContext.save()
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .overlay {
                if project.timelineTracks.isEmpty {
                    ZStack {
                        Color("PrimaryAccent")
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.day.timeline.left")
                                .font(.system(size: 32))
                                .foregroundStyle(Color("SecondaryText").opacity(0.3))
                            Text("Треков пока нет")
                                .font(.callout)
                                .foregroundStyle(Color("SecondaryText"))
                            Text("Нажмите «+» чтобы добавить")
                                .font(.caption)
                                .foregroundStyle(Color("SecondaryText").opacity(0.6))
                        }
                    }
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
                .popover(isPresented: $isAdding) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Новый трек")
                            .font(.headline)
                            .foregroundStyle(Color("PrimaryText"))
                        TextField("Название трека", text: $newTrackName)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(width: 220)
                            .glassEffect(in: .rect(cornerRadius: 8))
                            .onSubmit {
                                if !newTrackName.trimmingCharacters(in: .whitespaces).isEmpty {
                                    addTrack(); isAdding = false
                                }
                            }
                        HStack {
                            Button("Отмена") { newTrackName = ""; isAdding = false }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color("SecondaryText"))
                            Spacer()
                            Button("Создать") { addTrack(); isAdding = false }
                                .buttonStyle(.borderedProminent)
                                .disabled(newTrackName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .padding(18)
                }
            }
        }
        .popover(isPresented: Binding(
            get: { renamingTrack != nil },
            set: { if !$0 { renamingTrack = nil } }
        )) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Переименовать трек")
                    .font(.headline)
                    .foregroundStyle(Color("PrimaryText"))
                TextField("Название", text: $renamingTitle)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(width: 220)
                    .glassEffect(in: .rect(cornerRadius: 8))
                HStack {
                    Button("Отмена") { renamingTrack = nil }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color("SecondaryText"))
                    Spacer()
                    Button("Сохранить") {
                        renamingTrack?.title = renamingTitle
                        try? modelContext.save()
                        renamingTrack = nil
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(renamingTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(18)
        }
    }

    private func addTrack() {
        let title = newTrackName.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let track = TimelineTrack(title: title, orderIndex: project.timelineTracks.count)
        track.project = project
        project.timelineTracks.append(track)
        modelContext.insert(track)
        try? modelContext.save()
        newTrackName = ""
    }
}

// MARK: - Track Section (секция в общем редакторе)

private struct TrackSection: View {
    @Bindable var track: TimelineTrack
    let modelContext: ModelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Заголовок секции ───────────────────────────────────
            Text(track.title.isEmpty ? "Без названия" : track.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color("SecondaryText").opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.6)
                .padding(.horizontal, 36)
                .padding(.top, 32)
                .padding(.bottom, 8)

            Rectangle()
                .fill(Color("Border"))
                .frame(height: 0.5)
                .padding(.horizontal, 36)

            // ── Редактор ───────────────────────────────────────────
            ZStack(alignment: .topLeading) {
                if track.content.isEmpty {
                    Text("Заметки к треку «\(track.title)»...")
                        .foregroundStyle(Color("SecondaryText").opacity(0.4))
                        .font(.system(size: 17, design: .serif))
                        .padding(.top, 14)
                        .padding(.leading, 36)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $track.content)
                    .font(.system(size: 17, design: .serif))
                    .padding(.horizontal, 30)
                    .padding(.top, 8)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
            }
        }
        .onChange(of: track.content) { _, _ in
            try? modelContext.save()
        }
    }
}

// MARK: - Chapter Strip

private struct ChapterStrip: View {
    var chapters: [Chapter]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if chapters.isEmpty {
                    Text("Глав пока нет")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("SecondaryText").opacity(0.4))
                        .padding(.horizontal, 4)
                } else {
                    ForEach(chapters, id: \.id) { chapter in
                        ChapterChip(title: chapter.title.isEmpty ? "Без названия" : chapter.title)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        }
        .frame(height: 44)
        .background(Color("PrimaryAccent"))
    }
}

// MARK: - Chapter Chip

private struct ChapterChip: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color("PrimaryText").opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color("PrimaryText").opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Track Row

private struct TrackRow: View {
    let track: TimelineTrack
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.day.timeline.left")
                .foregroundStyle(Color("SecondaryText").opacity(0.6))
                .frame(width: 16)
            Text(track.title.isEmpty ? "Без названия" : track.title)
                .font(.body)
                .foregroundStyle(Color("PrimaryText"))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .contextMenu {
            Button("Переименовать", action: onRename)
            Divider()
            Button("Удалить", role: .destructive, action: onDelete)
        }
    }
}
