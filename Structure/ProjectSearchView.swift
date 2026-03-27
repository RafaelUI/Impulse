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
    var allowSemanticScenes: Bool                    // Включать ли семантический поиск по сценам

    // Готовые пресеты для разных воркспейсов
    static let book = SearchScope(
        allowKeywordTypes: [.chapter, .character, .worldResource,
                            .worldConcept, .worldStructure, .metaphysics],
        allowSemanticChapters: true,
        allowSemanticScenes: false
    )

    static let screenplay = SearchScope(
        allowKeywordTypes: [.scene, .screenRole],
        allowSemanticChapters: false,
        allowSemanticScenes: true
    )

    static let novel = SearchScope(
        allowKeywordTypes: [.chapter, .character],
        allowSemanticChapters: true,
        allowSemanticScenes: false
    )
}

// MARK: - ProjectSearchView

struct ProjectSearchView: View {
    let project: WritingProject
    let scope: SearchScope
    var onChapterSelect: (Chapter) -> Void = { _ in }
    var onCharacterSelect: (Character) -> Void = { _ in }
    var onSceneSelect: (ScreenScene) -> Void = { _ in }
    var onScreenRoleSelect: (ScreenRole) -> Void = { _ in }

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
    @State private var showEmpty = false
    @State private var emptyDelayTask: Task<Void, Never>? = nil
    @Namespace private var searchNS
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color("PrimaryAccent").ignoresSafeArea()

                // ── Декор — исчезает по opacity, не перестраивает дерево ──
                VStack(spacing: 10) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(Color("AccentColor").opacity(0.4))
                    Text("Поиск по проекту")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(Color("PrimaryText"))
                }
                .frame(maxWidth: .infinity)
                // Центрируем выше строки поиска: строка на height/2 - 90, декор — ещё на 100 выше
                .offset(y: geo.size.height / 2 - 190)
                .opacity(hasSearched ? 0 : 1)
                .allowsHitTesting(!hasSearched)

                Text("Поиск по словам — мгновенно\nСемантический поиск по тексту глав — глубоко")
                    .font(.caption)
                    .foregroundStyle(Color("SecondaryText").opacity(0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .offset(y: geo.size.height / 2 - 30)
                    .opacity(hasSearched ? 0 : 1)
                    .allowsHitTesting(false)

                // ── Результаты — всегда в дереве, показываются по opacity ──
                VStack(spacing: 0) {
                    Color.clear.frame(height: 56)
                    Divider()

                    if showEmpty && keywordResults.isEmpty && semanticResults.isEmpty && !isSemanticRunning {
                        ContentUnavailableView(
                            "Ничего не найдено",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("Попробуйте другую формулировку")
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                if !keywordResults.isEmpty {
                                    sectionHeader(icon: "textformat.abc", title: "По словам", count: keywordResults.count)
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
                                if scope.allowSemanticChapters || scope.allowSemanticScenes {
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
                                            Text(scope.allowSemanticScenes ? "Анализируем текст сцен..." : "Анализируем текст глав...")
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
                            .animation(.spring(duration: 1.0, bounce: 0.15), value: keywordResults.map(\.id))
                            .animation(.spring(duration: 1.0, bounce: 0.15), value: semanticResults.map(\.id))
                        }
                    }
                }
                .opacity(hasSearched ? 1 : 0)
                .allowsHitTesting(hasSearched)

                // ── Строка поиска — ОДИН экземпляр, двигается через padding ──
                searchFieldView
                    .matchedGeometryEffect(id: "searchBar", in: searchNS)
                    .frame(maxWidth: hasSearched ? .infinity : 520)
                    .padding(.horizontal, 16)
                    .padding(.top, hasSearched ? 10 : geo.size.height / 2 - 90)
            }
            .animation(.spring(duration: 1.3, bounce: 0.08), value: hasSearched)
        }
        .background(Color("PrimaryAccent"))
    }

    // ── TextField — единственный экземпляр во всём view ────────────────
    private var searchFieldView: some View {
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
                Button { clearSearch() } label: {
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
        title: LocalizedStringKey,
        count: Int,
        isLoading: Bool = false,
        progress: Int = 0,
        total: Int = 0
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Color("AccentColor").opacity(0.7))
            Text(title)
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
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let found = service.keywordSearch(query: trimmed, in: project)
                .filter { scope.allowKeywordTypes.contains($0.type) }
            await MainActor.run {
                withAnimation(.spring(duration: 1.8, bounce: 0.15)) {
                    keywordResults = found
                    hasSearched = true
                }
            }
        }

        // Semantic — после 400ms паузы
        if scope.allowSemanticChapters || scope.allowSemanticScenes {
            semanticTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await runSemanticSearch(query: trimmed)
            }
        }

        // "Ничего не найдено" — только через 2 секунды
        emptyDelayTask = Task {
            try? await Task.sleep(for: .seconds(2))
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
        if scope.allowSemanticScenes {
            let scenes = project.scenes ?? []
            guard !scenes.isEmpty else { return }

            await MainActor.run {
                semanticResults = []
                isSemanticRunning = true
                semanticProgress = 0
                semanticTotal = scenes.count
            }

            await service.semanticSceneSearch(
                query: query,
                scenes: scenes
            ) { result in
                var updated = semanticResults
                updated.append(result)
                updated.sort { $0.score > $1.score }
                semanticResults = updated
                semanticProgress += 1
            }
        } else if scope.allowSemanticChapters {
            let chapters = project.chapters ?? []
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
                var updated = semanticResults
                updated.append(result)
                updated.sort { $0.score > $1.score }
                semanticResults = updated
                semanticProgress += 1
            }
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
        if let chapter    = result.chapter    { onChapterSelect(chapter) }
        if let character  = result.character  { onCharacterSelect(character) }
        if let scene      = result.scene      { onSceneSelect(scene) }
        if let screenRole = result.screenRole { onScreenRoleSelect(screenRole) }
    }
}
