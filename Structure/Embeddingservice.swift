import Foundation
import CoreML
import Combine

// MARK: - Search Result

struct SearchResult: Identifiable {
    let id = UUID()
    let type: SearchResultType
    let title: String
    let snippet: String
    let score: Float
    // Целевые объекты — только один будет заполнен
    var chapter: Chapter?           = nil
    var character: Character?       = nil
    var worldResource: WorldResource?       = nil
    var worldConcept: WorldConcept?         = nil
    var worldStructure: WorldStructure?     = nil
    var worldMetaphysics: MetaphysicsConcept? = nil
    // Screenplay
    var scene: ScreenScene?          = nil
    var screenRole: ScreenRole?     = nil
}

enum SearchResultType: String {
    case chapter        = "Глава"
    case character      = "Персонаж"
    case worldResource  = "Ресурс мира"
    case worldConcept   = "Концепция"
    case worldStructure = "Структура мира"
    case metaphysics    = "Метафизика"
    case scene          = "Сцена"
    case screenRole     = "Роль"
    var icon: String {
        switch self {
        case .chapter:        return "doc.text"
        case .character:      return "person.fill"
        case .worldResource:  return "sparkles"
        case .worldConcept:   return "lightbulb.fill"
        case .worldStructure: return "building.columns.fill"
        case .metaphysics:    return "atom"
        case .scene:          return "film"
        case .screenRole:     return "person.crop.rectangle"
        }
    }
}

// MARK: - Search Mode

enum SearchMode: String, CaseIterable {
    case semantic = "По смыслу"
    case keyword  = "По словам"
    case combined = "Комбинированный"}

// MARK: - Embedding Service

@MainActor
final class EmbeddingService: ObservableObject {

    static let shared = EmbeddingService()

    private var model: LiteraryMiniLM?
    private var vocab: [String: Int] = [:]

    private let maxLength = 128
    private let clsToken  = 101
    private let sepToken  = 102
    private let padToken  = 0
    private let unkToken  = 100

    @Published var isReady = false
    @Published var isSearching = false

    private init() {
        Task { await load() }
    }

    private func load() async {
        let loadedMLModel: MLModel? = await Task.detached(priority: .background) {
            guard let url = Bundle.main.url(forResource: "LiteraryMiniLM", withExtension: "mlmodelc")
                         ?? Bundle.main.url(forResource: "LiteraryMiniLM", withExtension: "mlpackage") else {
                return nil
            }
            let config = MLModelConfiguration()
            config.computeUnits = .all
            return try? MLModel(contentsOf: url, configuration: config)
        }.value
        let loadedModel: LiteraryMiniLM? = loadedMLModel.map { LiteraryMiniLM(model: $0) }

        guard let vocabURL = Bundle.main.url(forResource: "vocab", withExtension: "txt"),
              let content = try? String(contentsOf: vocabURL, encoding: .utf8) else {
            return
            return
        }

        var loadedVocab: [String: Int] = [:]
        for (index, line) in content.components(separatedBy: "\n").enumerated() {
            let token = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty { loadedVocab[token] = index }
        }

        self.model = loadedModel
        self.vocab = loadedVocab
        self.isReady = loadedModel != nil

    }

    // MARK: - Главный метод поиска

    func search(query: String, in project: WritingProject, mode: SearchMode = .combined) async -> [SearchResult] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }

        isSearching = true
        defer { isSearching = false }

        switch mode {
        case .keyword:
            return keywordSearch(query: q, in: project)
        case .semantic:
            return await semanticSearch(query: q, in: project)
        case .combined:
            // Запускаем оба параллельно, затем объединяем
            async let semantic = semanticSearch(query: q, in: project)
            let keyword = keywordSearch(query: q, in: project)
            let semResults = await semantic
            return merge(semantic: semResults, keyword: keyword)
        }
    }

    // MARK: - Keyword Search (по всем типам данных)

    func keywordSearch(query: String, in project: WritingProject) -> [SearchResult] {
        let terms = query.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 1 }
        guard !terms.isEmpty else { return [] }

        var results: [SearchResult] = []

        // Главы — по названию и тексту
        for chapter in project.chapters ?? [] {
            let fields = [chapter.title, chapter.text, chapter.notes]
            if let (score, snippet) = keywordScore(terms: terms, in: fields, fullText: chapter.text) {
                results.append(SearchResult(
                    type: .chapter,
                    title: chapter.title.isEmpty ? "Без названия" : chapter.title,
                    snippet: snippet,
                    score: score,
                    chapter: chapter
                ))
            }
        }

        // Персонажи — по всем полям
        for character in project.characters ?? [] {
            let fields = [character.name, character.role, character.biography,
                         character.appearance, character.plotRole,
                         character.abilities]
            let fullText = fields.joined(separator: " ")
            if let (score, snippet) = keywordScore(terms: terms, in: fields, fullText: fullText) {
                results.append(SearchResult(
                    type: .character,
                    title: character.name,
                    snippet: snippet,
                    score: score,
                    character: character
                ))
            }
        }

        // Сцены (сценарий) — ищем по заголовку, заметкам и текстам всех вариаций
        for scene in project.scenes ?? [] {
            let variationTexts = scene.variations.map { $0.text }
            let allVariationsText = variationTexts.joined(separator: " ")
            let fields = [scene.title, allVariationsText, scene.notes]
            let bestSnippetSource = variationTexts.first(where: { !$0.isEmpty }) ?? scene.text
            if let (score, snippet) = keywordScore(terms: terms, in: fields, fullText: bestSnippetSource) {
                results.append(SearchResult(
                    type: .scene,
                    title: scene.title.isEmpty ? "Без названия" : scene.title,
                    snippet: snippet,
                    score: score,
                    scene: scene
                ))
            }
        }

        // Роли (сценарий)
        for role in project.screenRoles ?? [] {
            let fields = [role.name, role.role, role.biography, role.appearance, role.plotRole, role.abilities]
            let fullText = fields.joined(separator: " ")
            if let (score, snippet) = keywordScore(terms: terms, in: fields, fullText: fullText) {
                results.append(SearchResult(
                    type: .screenRole,
                    title: role.name,
                    snippet: snippet,
                    score: score,
                    screenRole: role
                ))
            }
        }

        // Мироустройство
        if let world = project.worldBuilding {

            for resource in world.resources ?? [] {
                let fields = [resource.name, resource.details, resource.rules, resource.limitations]
                if let (score, snippet) = keywordScore(terms: terms, in: fields, fullText: fields.joined(separator: " ")) {
                    results.append(SearchResult(
                        type: .worldResource,
                        title: resource.name,
                        snippet: snippet,
                        score: score,
                        worldResource: resource
                    ))
                }
            }

            for concept in world.concepts ?? [] {
                let fields = [concept.name, concept.details, concept.category]
                if let (score, snippet) = keywordScore(terms: terms, in: fields, fullText: fields.joined(separator: " ")) {
                    results.append(SearchResult(
                        type: .worldConcept,
                        title: concept.name,
                        snippet: snippet,
                        score: score,
                        worldConcept: concept
                    ))
                }
            }

            for structure in world.structures ?? [] {
                let fields = [structure.name, structure.type, structure.details]
                if let (score, snippet) = keywordScore(terms: terms, in: fields, fullText: fields.joined(separator: " ")) {
                    results.append(SearchResult(
                        type: .worldStructure,
                        title: structure.name,
                        snippet: snippet,
                        score: score,
                        worldStructure: structure
                    ))
                }
            }

            for meta in world.metaphysics ?? [] {
                let fields = [meta.name, meta.details, meta.implications]
                if let (score, snippet) = keywordScore(terms: terms, in: fields, fullText: fields.joined(separator: " ")) {
                    results.append(SearchResult(
                        type: .metaphysics,
                        title: meta.name,
                        snippet: snippet,
                        score: score,
                        worldMetaphysics: meta
                    ))
                }
            }
        }

        return results.sorted { $0.score > $1.score }
    }

    // MARK: - Semantic Chapter Search (sliding window по тексту глав)
    //
    // Делит текст главы на перекрывающиеся куски по chunkSize токенов,
    // считает эмбеддинг каждого куска и берёт максимальную схожесть.
    // Результаты отдаёт через AsyncStream — по одной главе за раз,
    // чтобы UI мог показывать их прогрессивно.

    func semanticChapterSearch(
        query: String,
        chapters: [Chapter],
        threshold: Float = 0.30,
        onResult: @escaping (SearchResult) -> Void
    ) async {
        guard isReady else { return }
        guard let queryEmbedding = embed(text: query) else { return }

        let chunkSize   = 100   // токены на кусок (оставляем запас до 128)
        let chunkOverlap = 20   // перекрытие между кусками

        for chapter in chapters {
            // Не ищем семантически по главам без текста — только название даёт ненадёжные скоры
            guard !chapter.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let fullText = [chapter.title, chapter.text]
                .filter { !$0.isEmpty }.joined(separator: " ")
            guard !fullText.isEmpty else { continue }

            // Токенизируем весь текст один раз — используем слова как единицу разбивки
            let words = fullText.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }

            guard !words.isEmpty else { continue }

            // Строим куски слов и считаем эмбеддинг каждого
            var bestScore: Float = 0
            let stride = max(chunkSize - chunkOverlap, 1)
            var start = 0

            while start < words.count {
                let end = min(start + chunkSize, words.count)
                let chunkWords = words[start..<end]
                let chunkText = chunkWords.joined(separator: " ")

                if let chunkEmb = embed(text: chunkText) {
                    let score = cosineSimilarity(queryEmbedding, chunkEmb)
                    if score > bestScore { bestScore = score }
                }

                if end == words.count { break }
                start += stride
            }

            if bestScore > threshold {
                let result = SearchResult(
                    type: .chapter,
                    title: chapter.title.isEmpty ? "Без названия" : chapter.title,
                    snippet: makeSnippet(from: chapter.text, query: query),
                    score: bestScore,
                    chapter: chapter
                )
                onResult(result)
            }

            // Даём UI шанс обновиться между главами
            await Task.yield()
        }
    }

    // MARK: - Semantic Scene Search (sliding window по тексту вариаций сцен)

    func semanticSceneSearch(
        query: String,
        scenes: [ScreenScene],
        threshold: Float = 0.18,
        onResult: @escaping (SearchResult) -> Void
    ) async {
        guard isReady else { return }
        guard let queryEmbedding = embed(text: query) else { return }

        let chunkSize    = 100
        let chunkOverlap = 20
        let stride       = max(chunkSize - chunkOverlap, 1)

        for scene in scenes {
            // Объединяем тексты всех вариаций для полноты поиска
            let variationTexts = scene.variations.map { $0.text }.filter { !$0.isEmpty }
            let fullText = ([scene.title] + variationTexts)
                .filter { !$0.isEmpty }.joined(separator: " ")
            guard !fullText.isEmpty else { continue }

            let words = fullText.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            guard !words.isEmpty else { continue }

            var bestScore: Float = 0
            var start = 0

            while start < words.count {
                let end = min(start + chunkSize, words.count)
                let chunkText = words[start..<end].joined(separator: " ")

                if let chunkEmb = embed(text: chunkText) {
                    let score = cosineSimilarity(queryEmbedding, chunkEmb)
                    if score > bestScore { bestScore = score }
                }

                if end == words.count { break }
                start += stride
            }

            if bestScore > threshold {
                let snippetSource = variationTexts.first ?? ""
                let result = SearchResult(
                    type: .scene,
                    title: scene.title.isEmpty ? "Без названия" : scene.title,
                    snippet: makeSnippet(from: snippetSource, query: query),
                    score: bestScore,
                    scene: scene
                )
                onResult(result)
            }

            await Task.yield()
        }
    }

    // MARK: - Semantic Search (главы + персонажи)

    func semanticSearch(query: String, in project: WritingProject) async -> [SearchResult] {
        guard isReady else { return [] }
        guard let queryEmbedding = embed(text: query) else { return [] }

        var results: [SearchResult] = []

        for chapter in project.chapters ?? [] {
            let text = [chapter.title, chapter.text].filter { !$0.isEmpty }.joined(separator: " ")
            guard !text.isEmpty, let emb = embed(text: text) else { continue }
            let score = cosineSimilarity(queryEmbedding, emb)
            if score > 0.20 {
                results.append(SearchResult(
                    type: .chapter,
                    title: chapter.title.isEmpty ? "Без названия" : chapter.title,
                    snippet: makeSnippet(from: chapter.text, query: query),
                    score: score,
                    chapter: chapter
                ))
            }
        }

        for character in project.characters ?? [] {
            let text = [character.name, character.role, character.biography,
                        character.appearance, character.plotRole]
                .filter { !$0.isEmpty }.joined(separator: " ")
            guard !text.isEmpty, let emb = embed(text: text) else { continue }
            let score = cosineSimilarity(queryEmbedding, emb)
            if score > 0.20 {
                let snippet = [character.role, character.biography].first(where: { !$0.isEmpty }) ?? ""
                results.append(SearchResult(
                    type: .character,
                    title: character.name,
                    snippet: String(snippet.prefix(120)),
                    score: score,
                    character: character
                ))
            }
        }

        return results.sorted { $0.score > $1.score }
    }

    // MARK: - Merge: объединение семантики и ключевых слов

    private func merge(semantic: [SearchResult], keyword: [SearchResult]) -> [SearchResult] {
        var merged: [String: SearchResult] = [:]

        // Ключ для дедупликации — тип + заголовок (lower-cased для надёжности)
        func key(_ r: SearchResult) -> String { "\(r.type.rawValue):\(r.title.lowercased())" }

        for result in semantic {
            merged[key(result)] = result
        }

        for result in keyword {
            let k = key(result)
            if let existing = merged[k] {
                // Оба метода нашли один элемент — берём лучший score и дополнительно бустим
                let combined = min(max(existing.score, result.score) + 0.05, 1.0)
                merged[k] = SearchResult(
                    type: existing.type,
                    title: existing.title,
                    snippet: existing.snippet.isEmpty ? result.snippet : existing.snippet,
                    score: combined,
                    chapter: existing.chapter,
                    character: existing.character,
                    worldResource: existing.worldResource ?? result.worldResource,
                    worldConcept: existing.worldConcept ?? result.worldConcept,
                    worldStructure: existing.worldStructure ?? result.worldStructure,
                    worldMetaphysics: existing.worldMetaphysics ?? result.worldMetaphysics
                )
            } else {
                // Только keyword нашёл (мироустройство, таймлайн) — включаем как есть
                merged[k] = result
            }
        }

        return merged.values.sorted { $0.score > $1.score }
    }

    // MARK: - Keyword Scoring

    /// Возвращает (score, snippet) если хотя бы один термин найден
    private func keywordScore(terms: [String], in fields: [String], fullText: String) -> (Float, String)? {
        let lowerFields = fields.map { $0.lowercased() }

        var matchCount = 0
        var totalWeight: Float = 0
        var bestSnippet = ""

        for term in terms {
            for (i, field) in lowerFields.enumerated() {
                if field.contains(term) {
                    matchCount += 1
                    // Первое поле (обычно название) весит больше
                    totalWeight += i == 0 ? 2.0 : 1.0

                    if bestSnippet.isEmpty {
                        bestSnippet = makeSnippet(from: fields[i], query: term)
                    }
                }
            }
        }

        guard matchCount > 0 else { return nil }

        // Нормализуем score: совпадение в названии (вес 2) vs тексте (вес 1).
        // Диапазон 0.3–0.95: title-only → ~0.3, полное покрытие → ~0.95.
        let maxPossible = Float(terms.count) * 2.0   // лучший случай: все термины в названии
        let normalized = min(totalWeight / maxPossible, 1.0)
        let score = Float(0.30) + normalized * Float(0.65)

        return (score, bestSnippet)
    }

    // MARK: - Embedding

    private func embed(text: String) -> [Float]? {
        guard let model else { return nil }
        let tokens = tokenize(text: text)
        guard !tokens.inputIDs.isEmpty else { return nil }
        guard let inputIDs = makeMultiArray(tokens.inputIDs),
              let attnMask = makeMultiArray(tokens.attentionMask) else { return nil }
        let input = LiteraryMiniLMInput(input_ids: inputIDs, attention_mask: attnMask)
        guard let output = try? model.prediction(input: input) else { return nil }
        let emb = output.embeddings
        var result = [Float](repeating: 0, count: emb.count)
        for i in 0..<emb.count { result[i] = emb[i].floatValue }
        return result
    }
    // MARK: - Токенайзер

    private struct TokenizerOutput {
        var inputIDs: [Int]
        var attentionMask: [Int]
        var tokenTypeIDs: [Int]
    }

    private func tokenize(text: String) -> TokenizerOutput {
        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        var ids: [Int] = [clsToken]
        for word in words {
            let pieces = wordPiece(word: word)
            // Оставляем место для [SEP]: максимум maxLength - 1 токенов перед добавлением
            if ids.count + pieces.count > maxLength - 1 {
                // Добавляем только то, что влезает
                let remaining = (maxLength - 1) - ids.count
                if remaining > 0 { ids.append(contentsOf: pieces.prefix(remaining)) }
                break
            }
            ids.append(contentsOf: pieces)
        }
        ids.append(sepToken)
        // Гарантируем точный размер maxLength
        ids = Array(ids.prefix(maxLength))

        let realLength = ids.count
        while ids.count < maxLength { ids.append(padToken) }

        let mask  = (0..<maxLength).map { $0 < realLength ? 1 : 0 }
        let types = [Int](repeating: 0, count: maxLength)
        return TokenizerOutput(inputIDs: ids, attentionMask: mask, tokenTypeIDs: types)
    }

    private func wordPiece(word: String) -> [Int] {
        if let id = vocab[word] { return [id] }
        var tokens: [Int] = []
        var remaining = word
        while !remaining.isEmpty {
            var found = false
            let prefix = tokens.isEmpty ? "" : "##"
            for length in stride(from: remaining.count, through: 1, by: -1) {
                let candidate = prefix + String(remaining.prefix(length))
                if let id = vocab[candidate] {
                    tokens.append(id)
                    remaining = String(remaining.dropFirst(length))
                    found = true
                    break
                }
            }
            if !found { tokens.append(unkToken); break }
        }
        return tokens
    }

    private func makeMultiArray(_ values: [Int]) -> MLMultiArray? {
        guard let arr = try? MLMultiArray(shape: [1, NSNumber(value: maxLength)], dataType: .int32) else { return nil }
        for (i, v) in values.prefix(maxLength).enumerated() { arr[i] = NSNumber(value: Int32(v)) }
        return arr
    }

    private func meanPool(_ multiArray: MLMultiArray, mask: [Int]) -> [Float] {
        let shape = multiArray.shape
        guard shape.count == 3 else { return [] }
        let seqLen = shape[1].intValue, hiddenSize = shape[2].intValue
        var result = [Float](repeating: 0, count: hiddenSize)
        var count: Float = 0
        for t in 0..<min(seqLen, mask.count) where mask[t] == 1 {
            for h in 0..<hiddenSize { result[h] += multiArray[t * hiddenSize + h].floatValue }
            count += 1
        }
        if count > 0 { result = result.map { $0 / count } }
        return normalize(result)
    }

    private func normalize(_ v: [Float]) -> [Float] {
        let norm = sqrt(v.reduce(0) { $0 + $1 * $1 })
        return norm > 0 ? v.map { $0 / norm } : v
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }
        return zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
    }

    private func makeSnippet(from text: String, query: String) -> String {
        let words = query.lowercased().components(separatedBy: .whitespaces)
        let lower = text.lowercased()
        for word in words {
            if let range = lower.range(of: word) {
                let start = lower.index(range.lowerBound, offsetBy: -60, limitedBy: lower.startIndex) ?? lower.startIndex
                let end   = lower.index(range.upperBound, offsetBy: 80,  limitedBy: lower.endIndex)   ?? lower.endIndex
                return "..." + String(text[start..<end]) + "..."
            }
        }
        return String(text.prefix(120))
    }
}
