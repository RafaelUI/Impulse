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
    /// Ограничить выдачу конкретными типами. Nil — все типы (поведение по умолчанию).
    var allowedTypes: Set<SearchResultType>? = nil
    let onSelect: (SearchResult) -> Void

    @ObservedObject private var service = EmbeddingService.shared
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
                    .foregroundStyle(isFocused ? Color("AccentColor") : Color("SecondaryText"))
                    .font(.system(size: 14))
                    .animation(.easeInOut(duration: 0.15), value: isFocused)

                TextField("Search documents...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isFocused)
                    .onSubmit { confirmFirst() }
                    .onChange(of: query) { _, new in scheduleSearch(new) }

                if !query.isEmpty {
                    Button {
                        clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color("SecondaryText").opacity(0.5))
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color("Editor"), in: Capsule())
            .overlay(Capsule().stroke(Color("SecondaryText").opacity(isFocused ? 0.25 : 0), lineWidth: 1))

            // ── Выпадающие результаты ──────────────────────────────
            .popover(isPresented: $isExpanded, arrowEdge: .bottom) {
                let visible = Array(results.prefix(15))
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visible, id: \.id) { result in
                            SearchDropdownRow(result: result) {
                                onSelect(result)
                                clearSearch()
                            }
                            if result.id != visible.last?.id {
                                Divider().padding(.leading, 50)
                            }
                        }
                    }
                }
                .frame(width: 400, height: min(CGFloat(visible.count) * 56, 500))
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
            // Тулбар-поиск — только по ключевым словам, быстро и без CoreML
            var found = service.keywordSearch(query: text, in: project)
            if let allowed = allowedTypes {
                found = found.filter { allowed.contains($0.type) }
            }
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
                    Image(systemName: result.type.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(Color("AccentColor"))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(result.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color("PrimaryText"))
                        .lineLimit(1)
                    if !result.snippet.isEmpty {
                        Text(result.snippet)
                            .font(.system(size: 11))
                            .foregroundStyle(Color("SecondaryText"))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(LocalizedStringKey(result.type.rawValue))
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

