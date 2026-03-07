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

    var body: some View {
        HStack(spacing: 0) {
            // ── Левая колонка: список треков ──────────────────────
            trackList
                .frame(width: 220)
                .background(Color("PrimaryAccent"))

            Rectangle()
                .fill(Color("Border"))
                .frame(width: 0.5)

            // ── Правая часть: общий редактор ──────────────────────
            if let track = selectedTrack {
                TrackEditorView(track: track)
                    .frame(maxWidth: .infinity)
                    .background(Color("Editor"))
            } else {
                ZStack {
                    Color("Editor").ignoresSafeArea()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.day.timeline.left")
                            .font(.system(size: 36))
                            .foregroundStyle(Color("SecondaryText").opacity(0.4))
                        Text("Выберите трек")
                            .font(.body)
                            .foregroundStyle(Color("SecondaryText"))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Track List

    @ViewBuilder
    private var trackList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(sorted, id: \.id) { track in
                    TrackRow(
                        track: track,
                        isSelected: selectedTrack?.persistentModelID == track.persistentModelID,
                        onSelect: { selectedTrack = track },
                        onRename: {
                            renamingTrack = track
                            renamingTitle = track.title
                        },
                        onDelete: {
                            if selectedTrack?.id == track.id { selectedTrack = nil }
                            modelContext.delete(track)
                            try? modelContext.save()
                        }
                    )
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color("PrimaryAccent"))
        .overlay {
            if project.timelineTracks.isEmpty {
                ZStack {
                    Color("PrimaryAccent").ignoresSafeArea()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.day.timeline.left")
                            .font(.system(size: 36))
                            .foregroundStyle(Color("SecondaryText").opacity(0.4))
                        Text("Треков пока нет")
                            .foregroundStyle(Color("SecondaryText"))
                        Text("Нажмите «+» чтобы добавить")
                            .font(.caption)
                            .foregroundStyle(Color("SecondaryText").opacity(0.6))
                    }
                }
            }
        }
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
        selectedTrack = track
        newTrackName = ""
    }
}

// MARK: - Track Row

private struct TrackRow: View {
    let track: TimelineTrack
    let isSelected: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: "calendar.day.timeline.left")
                    .foregroundStyle(isSelected ? Color("AccentColor") : Color("SecondaryText").opacity(0.6))
                    .frame(width: 16)
                Text(track.title.isEmpty ? "Без названия" : track.title)
                    .font(.body)
                    .foregroundStyle(isSelected ? Color("AccentColor") : Color("PrimaryText"))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color("AccentColor").opacity(0.12) : Color.clear)
            )
            .padding(.horizontal, 10)
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

// MARK: - Track Editor

private struct TrackEditorView: View {
    @Bindable var track: TimelineTrack
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack(alignment: .topLeading) {
            if track.content.isEmpty {
                Text("Начните писать заметки к треку...")
                    .foregroundStyle(Color("SecondaryText").opacity(0.6))
                    .font(.system(size: 17, design: .serif))
                    .padding(.top, 48)
                    .padding(.leading, 36)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $track.content)
                .font(.system(size: 17, design: .serif))
                .padding(.horizontal, 30)
                .padding(.top, 40)
                .scrollContentBackground(.hidden)
        }
        .background(Color("Editor"))
        .onChange(of: track.content) { _, _ in
            try? modelContext.save()
        }
    }
}
