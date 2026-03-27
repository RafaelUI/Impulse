import SwiftUI
import SwiftData

// MARK: - Timeline Workspace

struct TimelineWorkspaceView: View {
    @Bindable var project: WritingProject
    @Binding var selectedTrack: TimelineTrack?
    /// Если передан — используется как шапка колонок; иначе берутся главы проекта.
    var columns: [TimelineColumnItem]? = nil
    /// Кастомный сайдбар для выбранного узла. Если nil — используется стандартный (с персонажами и локациями).
    var sidebarView: ((TimelineTrack, UUID, @escaping () -> Void, @escaping () -> Void) -> AnyView)? = nil
    @Environment(\.modelContext) private var modelContext

    @State private var isAdding = false
    @State private var newTrackName = ""
    @State private var renamingTrack: TimelineTrack? = nil
    @State private var renamingTitle = ""
    @State private var canvasScale: CGFloat = 1.0

    /// Выбранный узел: (trackIdx, nodeID)
    @State private var selectedNode: (trackIdx: Int, nodeID: UUID)? = nil

    private var sorted: [TimelineTrack] {
        (project.timelineTracks ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    private var resolvedColumns: [TimelineColumnItem] {
        if let columns { return columns }
        return (project.chapters ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { TimelineColumnItem(id: $0.id, title: $0.title) }
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

            // ── Правая часть: канвас + sidebar поверх ─────────────
            ZStack(alignment: .trailing) {
                TimelineCanvasScrollView(
                    tracks: sorted,
                    columns: resolvedColumns,
                    scale: canvasScale,
                    onSave: { try? modelContext.save() },
                    onSelectNode: { sel in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedNode = sel
                        }
                    }
                )

                // Ползунок масштаба — правый нижний угол
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        TimelineScaleSlider(scale: $canvasScale)
                            .frame(width: 220)
                            .padding(12)
                    }
                }

                // Sidebar поверх канваса
                if let sel = selectedNode,
                   sel.trackIdx < sorted.count {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color("Border"))
                            .frame(width: 0.5)
                        let track = sorted[sel.trackIdx]
                        let closeSidebar = {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedNode = nil }
                        }
                        let saveFn = { try? modelContext.save() }
                        if let builder = sidebarView {
                            builder(track, sel.nodeID, { saveFn() }, closeSidebar)
                        } else {
                            TimelineNodeSidebarView(
                                track: track,
                                nodeID: sel.nodeID,
                                project: project,
                                onSave: { saveFn() },
                                onClose: closeSidebar
                            )
                        }
                    }
                    .frame(width: 281)
                    .background(Color("PrimaryAccent"))
                    .transition(.move(edge: .trailing))
                }
            }
        }
    }

    // MARK: - Track List

    @ViewBuilder
    private var trackList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Заголовок (высота = timelineHeaderHeight) ──────────
            Text("Треки")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color("PrimaryText").opacity(0.4))
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .frame(height: timelineHeaderHeight, alignment: .bottom)

            // ── Список ────────────────────────────────────────────
            ScrollView {
                VStack(spacing: 0) {
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
                        .frame(height: timelineTrackHeight)
                    }
                }
            }
            .overlay {
                if (project.timelineTracks ?? []).isEmpty {
                    ZStack {
                        Color("PrimaryAccent")
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.day.timeline.left")
                                .font(.system(size: 50))
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
        let track = TimelineTrack(title: title, orderIndex: (project.timelineTracks ?? []).count)
        track.project = project
        project.timelineTracks = (project.timelineTracks ?? []) + [track]
        modelContext.insert(track)
        try? modelContext.save()
        newTrackName = ""
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
// MARK: - Scale Slider

struct TimelineScaleSlider: View {
    @Binding var scale: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "minus")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color("AccentColor").opacity(0.8))
                .onTapGesture {
                    scale = max(0.25, scale - 0.25)
                }
            Slider(value: $scale, in: 0.25...4.0)
                .tint(Color("AccentColor"))
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color("AccentColor").opacity(0.8))
                .onTapGesture {
                    scale = min(4.0, scale + 0.25)
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color("Editor"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color("Border"), lineWidth: 0.5)
        )
    }
}

