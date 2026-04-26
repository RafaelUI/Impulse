import SwiftUI
import Combine

// MARK: - Search View Mode

enum SearchViewMode { case list, constellation }

// MARK: - Search View

struct SearchView: View {
    var project: WritingProject
    var onChapterSelect: (Chapter) -> Void
    var onCharacterSelect: (Character) -> Void

    @StateObject private var service = EmbeddingService.shared
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var hasSearched = false
    @State private var mode: SearchMode = .combined
    @State private var viewMode: SearchViewMode = .constellation

    var body: some View {
        VStack(spacing: 0) {

            // ── Поисковая строка ───────────────────────────────────
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color("SecondaryText"))

                TextField("Поиск по проекту...", text: $query)
                    .textFieldStyle(.plain)
                    .onSubmit { runSearch() }

                if service.isSearching {
                    ProgressView().controlSize(.small)
                } else if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                        hasSearched = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color("SecondaryText"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color("AccentColor").opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // ── Переключатель режима ───────────────────────────────
            HStack(spacing: 6) {
                ForEach(SearchMode.allCases, id: \.self) { m in
                    Button {
                        mode = m
                        if hasSearched { runSearch() }
                    } label: {
                        Text(LocalizedStringKey(m.rawValue))
                            .font(.system(size: 11, weight: mode == m ? .semibold : .regular))
                            .foregroundStyle(mode == m ? Color("AccentColor") : Color("SecondaryText"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                mode == m
                                ? Color("AccentColor").opacity(0.12)
                                : Color.clear,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if hasSearched && !results.isEmpty {
                    Text("\(results.count) результатов")
                        .font(.system(size: 11))
                        .foregroundStyle(Color("SecondaryText").opacity(0.6))

                    Button {
                        withAnimation(.spring(duration: 0.3, bounce: 0.1)) {
                            viewMode = viewMode == .list ? .constellation : .list
                        }
                    } label: {
                        Image(systemName: viewMode == .constellation ? "list.bullet" : "circle.grid.2x2")
                            .font(.system(size: 13))
                            .foregroundStyle(viewMode == .constellation
                                ? Color("AccentColor")
                                : Color("SecondaryText").opacity(0.5))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                viewMode == .constellation
                                    ? Color("AccentColor").opacity(0.12)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(viewMode == .constellation ? "Список" : "Созвездие")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            Divider()

            // ── Состояния ──────────────────────────────────────────
            if !service.isReady && mode != .keyword {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Загрузка модели поиска...")
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryText"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if hasSearched && results.isEmpty {
                ContentUnavailableView(
                    "Ничего не найдено",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Попробуйте другой режим или переформулируйте запрос")
                )

            } else if !results.isEmpty && viewMode == .list {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groupedResults, id: \.type) { group in
                            SearchGroupSection(
                                group: group,
                                onSelect: handleSelect
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }

            } else {
                ConstellationView(query: query, nodes: constellationNodes,
                                  onSelect: handleConstellationSelect)
            }
        }
        .background(Color("PrimaryAccent"))
    }

    // MARK: - Grouping

    private var groupedResults: [SearchGroup] {
        let order: [SearchResultType] = [.chapter, .character,
                                          .worldResource, .worldConcept,
                                          .worldStructure, .metaphysics]
        var groups: [SearchGroup] = []
        for type in order {
            let items = results.filter { $0.type == type }
            if !items.isEmpty {
                groups.append(SearchGroup(type: type, results: items))
            }
        }
        return groups
    }

    private func handleSelect(_ result: SearchResult) {
        if let chapter   = result.chapter   { onChapterSelect(chapter) }
        if let character = result.character { onCharacterSelect(character) }
        // Мироустройство и таймлайн — можно расширить навигацию позже
    }

    private var constellationNodes: [ConstellationNode] {
        results.map { r in
            ConstellationNode(id: r.id, chapter: r.title, score: r.score,
                              snippet: r.snippet, type: r.type)
        }
    }

    private func handleConstellationSelect(_ node: ConstellationNode) {
        if let result = results.first(where: { $0.id == node.id }) {
            handleSelect(result)
        }
    }

    private func runSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        Task {
            results = await service.search(query: q, in: project, mode: mode)
            hasSearched = true
        }
    }
}

// MARK: - Search Group

struct SearchGroup: Identifiable {
    var id: String { type.rawValue }
    let type: SearchResultType
    let results: [SearchResult]
}

struct SearchGroupSection: View {
    let group: SearchGroup
    let onSelect: (SearchResult) -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок группы
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: group.type.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(Color("AccentColor").opacity(0.7))
                    Text(group.type.rawValue.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Color("SecondaryText"))
                    Text("·  \(group.results.count)")
                        .font(.system(size: 10))
                        .foregroundStyle(Color("SecondaryText").opacity(0.6))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color("SecondaryText").opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(group.results) { result in
                    SearchResultRow(result: result) { onSelect(result) }
                    if result.id != group.results.last?.id {
                        Divider().padding(.leading, 60)
                    }
                }
            }

            Divider()
                .padding(.top, 4)
        }
    }
}

// MARK: - Result Row

struct SearchResultRow: View {
    let result: SearchResult
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("AccentColor").opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: result.type.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(Color("AccentColor"))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(result.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color("PrimaryText"))
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(result.score * 100))%")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color("SecondaryText").opacity(0.6))
                    }

                    if !result.snippet.isEmpty {
                        Text(result.snippet)
                            .font(.caption)
                            .foregroundStyle(Color("SecondaryText"))
                            .lineLimit(2)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isHovered ? Color("AccentColor").opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}


