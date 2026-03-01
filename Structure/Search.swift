import SwiftUI
import Combine

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

    var body: some View {
        VStack(spacing: 0) {

            // ── Поисковая строка ───────────────────────────────────
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

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
                            .foregroundStyle(.secondary)
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
                        Text(m.rawValue)
                            .font(.system(size: 11, weight: mode == m ? .semibold : .regular))
                            .foregroundStyle(mode == m ? Color("AccentColor") : .secondary)
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
                        .foregroundStyle(.tertiary)
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
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if !results.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Группируем по типу
                        ForEach(groupedResults, id: \.type) { group in
                            SearchGroupSection(
                                group: group,
                                onSelect: handleSelect
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }

            } else if hasSearched {
                ContentUnavailableView(
                    "Ничего не найдено",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Попробуйте другой режим или переформулируйте запрос")
                )

            } else {
                SearchHintView(mode: mode)
            }
        }
        .background(Color("PrimaryAccent"))
    }

    // MARK: - Grouping

    private var groupedResults: [SearchGroup] {
        let order: [SearchResultType] = [.chapter, .character, .timeline,
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
                        .foregroundStyle(.secondary)
                    Text("·  \(group.results.count)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
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
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(result.score * 100))%")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }

                    if !result.snippet.isEmpty {
                        Text(result.snippet)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

// MARK: - Hint

struct SearchHintView: View {
    let mode: SearchMode

    var hints: [(icon: String, text: String)] {
        switch mode {
        case .semantic:
            return [
                ("sparkles", "Ищет по смыслу, а не словам"),
                ("doc.text", "Главы и персонажи"),
                ("quote.bubble", "Понимает синонимы и контекст"),
            ]
        case .keyword:
            return [
                ("textformat.abc", "Точное совпадение слов"),
                ("globe.europe.africa", "Главы, персонажи, мироустройство"),
                ("calendar", "События таймлайна"),
            ]
        case .combined:
            return [
                ("sparkles", "Семантика + ключевые слова"),
                ("globe.europe.africa", "Все данные проекта"),
                ("arrow.up.arrow.down", "Объединённый рейтинг"),
            ]
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(Color("AccentColor").opacity(0.5))

            Text("Поиск по проекту")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(hints, id: \.text) { hint in
                    Label(hint.text, systemImage: hint.icon)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
