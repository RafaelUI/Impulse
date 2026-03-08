import SwiftUI

// MARK: - SearchScope
//
// Передаётся при вызове ProjectSearchView — определяет, что именно искать.
// Каждый воркспейс создаёт свой набор:
//
//   BookWorkspace:
//     ProjectSearchView(project: project, scope: .book, ...)
//
//   ScreenplayWorkspace (пример будущего):
//     ProjectSearchView(project: project, scope: .screenplay, ...)

struct SearchScope {
    var allowKeywordTypes: Set<SearchResultType>    // Типы для быстрого поиска по словам
    var allowSemanticChapters: Bool                  // Включать ли глубокий семантический поиск по тексту глав

    // Готовые пресеты для разных воркспейсов
    static let book = SearchScope(
        allowKeywordTypes: [.chapter, .character, .worldResource,
                            .worldConcept, .worldStructure, .metaphysics, .timeline],
        allowSemanticChapters: true
    )

    static let screenplay = SearchScope(
        allowKeywordTypes: [.chapter, .character],
        allowSemanticChapters: true
    )

    static let novel = SearchScope(
        allowKeywordTypes: [.chapter, .character],
        allowSemanticChapters: true
    )

    static let science = SearchScope(
        allowKeywordTypes: [.worldResource, .worldConcept, .worldStructure, .metaphysics],
        allowSemanticChapters: false
    )
}

// MARK: - ProjectSearchView

struct ProjectSearchView: View {
    let project: WritingProject
    let scope: SearchScope
    var onChapterSelect: (Chapter) -> Void = { _ in }
    var onCharacterSelect: (Character) -> Void = { _ in }

    @ObservedObject private var service = EmbeddingService.shared

    // Keyword search
    @State private var query = ""
    @State private var keywordResults: [SearchResult] = []
    @State private var keywordTask: Task<Void, Never>? = nil

    // Semantic search
    @State private var semanticResults: [SearchResult] = []
    @State private var semanticTask: Task<Void, Never>? = nil
    @State private var isSemanticRunning = false
    @State private var semanticProgress: Int = 0
    @State private var semanticTotal: Int = 0

    // UI state
    @State private var hasSearched = false
    @State private var showEmpty = false        // задержка перед "ничего не найдено"
    @State private var emptyDelayTask: Task<Void, Never>? = nil
    @State private var visibleResults: [SearchResult] = []  // для анимации по одному
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color("PrimaryAccent").ignoresSafeArea()

                // ── Иконка и подсказка — исчезают при поиске ───────────
                if !hasSearched {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(Color("AccentColor").opacity(0.4))
                        Text("Поиск по проекту")
                            .font(.title2.weight(.medium))
                            .foregroundStyle(Color("PrimaryText"))
                        searchBar
                            .frame(maxWidth: 520)
                            .padding(.top, 8)
                        Text("Поиск по словам — мгновенно\nСемантический поиск по тексту глав — глубоко")
                            .font(.caption)
                            .foregroundStyle(Color("SecondaryText").opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity)
                    // Центрируем вертикально
                    .offset(y: geo.size.height / 2 - 130)
                    .transition(.opacity)
                }

                // ── Строка поиска в режиме результатов ─────────────────
                if hasSearched {
                    VStack(spacing: 0) {
                        searchBar
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                        Divider()

                        // ── Результаты ─────────────────────────────────
                        if showEmpty && keywordResults.isEmpty && semanticResults.isEmpty && !isSemanticRunning {
                            ContentUnavailableView(
                                "Ничего не найдено",
                                systemImage: "doc.text.magnifyingglass",
                                description: Text("Попробуйте другую формулировку")
                            )
                            .transition(.opacity)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 0) {

                                    // ── По словам ──────────────────────
                                    if !keywordResults.isEmpty {
                                        sectionHeader(
                                            icon: "textformat.abc",
                                            title: "По словам",
                                            count: keywordResults.count
                                        )
                                        ForEach(keywordResults) { result in
                                            SearchResultRow(result: result) { handleSelect(result) }
                                                .transition(.asymmetric(
                                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                                    removal: .opacity
                                                ))
                                            if result.id != keywordResults.last?.id {
                                                Divider().padding(.leading, 60)
                                            }
                                        }
                                        Divider().padding(.top, 4)
                                    }

                                    // ── По смыслу ──────────────────────
                                    if scope.allowSemanticChapters {
                                        sectionHeader(
                                            icon: "sparkles",
                                            title: "По смыслу",
                                            count: semanticResults.count,
                                            isLoading: isSemanticRunning,
                                            progress: semanticProgress,
                                            total: semanticTotal
                                        )
                                        if semanticResults.isEmpty && isSemanticRunning {
                                            HStack {
                                                Spacer()
                                                Text("Анализируем текст глав...")
                                                    .font(.caption)
                                                    .foregroundStyle(Color("SecondaryText").opacity(0.6))
                                                Spacer()
                                            }
                                            .padding(.vertical, 16)
                                        } else {
                                            ForEach(semanticResults) { result in
                                                SearchResultRow(result: result) { handleSelect(result) }
                                                    .transition(.asymmetric(
                                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                                        removal: .opacity
                                                    ))
                                                if result.id != semanticResults.last?.id {
                                                    Divider().padding(.leading, 60)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                                .animation(.spring(duration: 1.8, bounce: 0.15), value: keywordResults.map(\.id))
                                .animation(.spring(duration: 1.8, bounce: 0.15), value: semanticResults.map(\.id))
                            }
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
        }
        .background(Color("PrimaryAccent"))
        .animation(.spring(duration: 0.45, bounce: 0.1), value: hasSearched)
    }

    // ── Строка поиска — единственный экземпляр в body ──────────────────
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(isSearchFocused ? Color("AccentColor") : Color("SecondaryText"))
                .font(.system(size: 15))
                .animation(.easeInOut(duration: 0.15), value: isSearchFocused)

            TextField("Поиск по проекту...", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($isSearchFocused)
                .onSubmit { runSearch() }
                .onChange(of: query) { _, new in scheduleSearch(new) }

            if isSemanticRunning {
                ProgressView()
                    .controlSize(.small)
                    .help("Семантический поиск: \(semanticProgress)/\(semanticTotal) глав")
            } else if !query.isEmpty {
                Button {
                    clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color("SecondaryText").opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color("Editor"), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color("AccentColor").opacity(isSearchFocused ? 0.3 : 0), lineWidth: 1)
                .animation(.easeInOut(duration: 0.15), value: isSearchFocused)
        )
    }

    // MARK: - Section Header

    @ViewBuilder
    private func sectionHeader(
        icon: String,
        title: String,
        count: Int,
        isLoading: Bool = false,
        progress: Int = 0,
        total: Int = 0
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Color("AccentColor").opacity(0.7))
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color("SecondaryText"))
            if count > 0 {
                Text("·  \(count)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color("SecondaryText").opacity(0.6))
            }
            Spacer()
            if isLoading && total > 0 {
                Text("\(progress)/\(total)")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(Color("AccentColor").opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color("PrimaryAccent"))
    }

    // MARK: - Logic

    private func scheduleSearch(_ text: String) {
        keywordTask?.cancel()
        semanticTask?.cancel()
        emptyDelayTask?.cancel()
        showEmpty = false

        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            clearSearch()
            return
        }

        // Keyword — дебаунс 150ms, результаты сразу
        keywordTask = Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            let found = service.keywordSearch(query: trimmed, in: project)
                .filter { scope.allowKeywordTypes.contains($0.type) }
            await MainActor.run {
                withAnimation(.spring(duration: 2, bounce: 0.15)) {
                    keywordResults = found
                    hasSearched = true
                }
            }
        }

        // Semantic — после 400ms паузы
        if scope.allowSemanticChapters {
            semanticTask = Task {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                await runSemanticSearch(query: trimmed)
            }
        }

        // "Ничего не найдено" — только через 2 секунды после последнего ввода
        emptyDelayTask = Task {
            try? await Task.sleep(for: .seconds(3.2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showEmpty = true
                }
            }
        }
    }

    private func runSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        scheduleSearch(trimmed)
    }

    private func runSemanticSearch(query: String) async {
        let chapters = project.chapters
        guard !chapters.isEmpty else { return }

        await MainActor.run {
            semanticResults = []
            isSemanticRunning = true
            semanticProgress = 0
            semanticTotal = chapters.count
        }

        await service.semanticChapterSearch(
            query: query,
            chapters: chapters
        ) { result in
            // onResult вызывается на том потоке, где работает EmbeddingService (@MainActor)
            // Вставляем результат в отсортированное место
            var updated = semanticResults
            updated.append(result)
            updated.sort { $0.score > $1.score }
            semanticResults = updated
            semanticProgress += 1
        }

        await MainActor.run {
            isSemanticRunning = false
        }
    }

    private func clearSearch() {
        keywordTask?.cancel()
        semanticTask?.cancel()
        emptyDelayTask?.cancel()
        query = ""
        keywordResults = []
        semanticResults = []
        isSemanticRunning = false
        hasSearched = false
        showEmpty = false
    }

    private func handleSelect(_ result: SearchResult) {
        if let chapter   = result.chapter   { onChapterSelect(chapter) }
        if let character = result.character { onCharacterSelect(character) }
    }
}
