import SwiftUI

// MARK: - WorkspaceSearchBar
// Переиспользуемый поиск. Написан один раз — вставляется в любой воркспейс.
//
// ИСПОЛЬЗОВАНИЕ (одна строка в любом воркспейсе):
//
//   WorkspaceSearchBar(project: project) { result in
//       if let chapter = result.chapter { selectedChapter = chapter }
//       if let char = result.character  { selectedCharacter = char }
//   }

struct WorkspaceSearchBar: View {
    let project: WritingProject
    let onSelect: (SearchResult) -> Void

    @StateObject private var service = EmbeddingService.shared
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var isExpanded = false
    @State private var searchTask: Task<Void, Never>? = nil
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {

            // ── Строка поиска ──────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(isFocused ? Color("AccentColor") : .secondary)
                    .font(.system(size: 13))
                    .animation(.easeInOut(duration: 0.15), value: isFocused)

                TextField("Поиск...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isFocused)
                    .onSubmit { confirmFirst() }
                    .onChange(of: query) { _, new in scheduleSearch(new) }

                if !query.isEmpty {
                    Button {
                        clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                } else {
                    // Подсказка с названием проекта
                    Text(project.title)
                        .font(.system(size: 11))
                        .foregroundStyle(.quaternary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color("AccentColor").opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            // ── Выпадающие результаты ──────────────────────────────
            .popover(isPresented: $isExpanded, arrowEdge: .bottom) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(results.prefix(8).enumerated()), id: \.element.id) { _, result in
                            SearchDropdownRow(result: result) {
                                onSelect(result)
                                clearSearch()
                            }
                            if result.id != results.prefix(8).last?.id {
                                Divider().padding(.leading, 50)
                            }
                        }
                    }
                }
                .frame(width: 320, height: min(CGFloat(results.count) * 52, 320))
            }
        }
        // Закрытие при клике за пределами
        .onChange(of: isFocused) { _, focused in
            if !focused { isExpanded = false }
        }
    }

    // MARK: - Logic

    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            isExpanded = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            let found = await service.search(query: text, in: project)
            await MainActor.run {
                results = found
                isExpanded = !found.isEmpty
            }
        }
    }

    private func confirmFirst() {
        guard let first = results.first else { return }
        onSelect(first)
        clearSearch()
    }

    private func clearSearch() {
        query = ""
        results = []
        isExpanded = false
        isFocused = false
    }
}

// MARK: - Dropdown Row

private struct SearchDropdownRow: View {
    let result: SearchResult
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color("AccentColor").opacity(0.10))
                        .frame(width: 28, height: 28)
                    Image(systemName: result.type == .chapter ? "doc.text" : "person.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("AccentColor"))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(result.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !result.snippet.isEmpty {
                        Text(result.snippet)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(result.type == .chapter ? "Глава" : "Персонаж")
                    .font(.system(size: 10))
                    .foregroundStyle(Color("AccentColor").opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color("AccentColor").opacity(0.08), in: Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovered ? Color("AccentColor").opacity(0.06) : Color.clear)
        .onHover { isHovered = $0 }
    }
}
