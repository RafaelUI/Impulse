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
    var timelineEvent: TimelineEvent?       = nil
}

enum SearchResultType: String {
    case chapter        = "Глава"
    case character      = "Персонаж"
    case worldResource  = "Ресурс мира"
    case worldConcept   = "Концепция"
    case worldStructure = "Структура мира"
    case metaphysics    = "Метафизика"
    case timeline       = "Таймлайн"

    var icon: String {
        switch self {
        case .chapter:        return "doc.text"
        case .character:      return "person.fill"
        case .worldResource:  return "sparkles"
        case .worldConcept:   return "lightbulb.fill"
        case .worldStructure: return "building.columns.fill"
        case .metaphysics:    return "atom"
        case .timeline:       return "calendar"
        }
    }
}

// MARK: - Search Mode

enum SearchMode: String, CaseIterable {
    case semantic = "По смыслу"
    case keyword  = "По словам"
    case combined = "Комбинированный"
}

// MARK: - Embedding Service

@MainActor
final class EmbeddingService: ObservableObject {

    static let shared = EmbeddingService()

    private var model: float16_model?
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

    // MARK: - Загрузка

    private func load() async {
        let loadedModel: float16_model? = await Task.detached(priority: .background) {
            guard let url = Bundle.main.url(forResource: "float16_model", withExtension: "mlmodelc")
                         ?? Bundle.main.url(forResource: "float16_model", withExtension: "mlpackage") else {
                return nil
            }
            let config = MLModelConfiguration()
            config.computeUnits = .all
            guard let mlModel = try? MLModel(contentsOf: url, configuration: config) else { return nil }
            return float16_model(model: mlModel)
        }.value

        guard let vocabURL = Bundle.main.url(forResource: "vocab", withExtension: "txt"),
              let content = try? String(contentsOf: vocabURL, encoding: .utf8) else {
            print("❌ vocab.txt не найден")
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
        print("✅ EmbeddingService готов, словарь: \(loadedVocab.count) токенов")
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
        for chapter in project.chapters {
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
        for character in project.characters {
            let fields = [character.name, character.role, character.biography,
                         character.appearance, character.plotRole,
                         character.abilities, character.locations]
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

        // Мироустройство
        if let world = project.worldBuilding {

            for resource in world.resources {
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

            for concept in world.concepts {
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

            for structure in world.structures {
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

            for meta in world.metaphysics {
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

        // Таймлайн — из глав и персонажей
        var allEvents: [TimelineEvent] = []
        allEvents += project.chapters.flatMap { $0.timeline }
        allEvents += project.characters.flatMap { $0.timeline }

        for event in allEvents {
            let fields = [event.title, event.details, event.date]
            if let (score, snippet) = keywordScore(terms: terms, in: fields, fullText: fields.joined(separator: " ")) {
                results.append(SearchResult(
                    type: .timeline,
                    title: event.title,
                    snippet: snippet,
                    score: score,
                    timelineEvent: event
                ))
            }
        }

        return results.sorted { $0.score > $1.score }
    }

    // MARK: - Semantic Search (главы + персонажи)

    func semanticSearch(query: String, in project: WritingProject) async -> [SearchResult] {
        guard isReady else { return [] }
        guard let queryEmbedding = embed(text: query) else { return [] }

        var results: [SearchResult] = []

        for chapter in project.chapters {
            let text = [chapter.title, chapter.text].filter { !$0.isEmpty }.joined(separator: " ")
            guard !text.isEmpty, let emb = embed(text: text) else { continue }
            let score = cosineSimilarity(queryEmbedding, emb)
            if score > 0.25 {
                results.append(SearchResult(
                    type: .chapter,
                    title: chapter.title.isEmpty ? "Без названия" : chapter.title,
                    snippet: makeSnippet(from: chapter.text, query: query),
                    score: score,
                    chapter: chapter
                ))
            }
        }

        for character in project.characters {
            let text = [character.name, character.role, character.biography,
                        character.appearance, character.plotRole]
                .filter { !$0.isEmpty }.joined(separator: " ")
            guard !text.isEmpty, let emb = embed(text: text) else { continue }
            let score = cosineSimilarity(queryEmbedding, emb)
            if score > 0.25 {
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

        // Ключ для дедупликации — тип + заголовок
        func key(_ r: SearchResult) -> String { "\(r.type.rawValue):\(r.title)" }

        for result in semantic {
            merged[key(result)] = result
        }

        for result in keyword {
            let k = key(result)
            if let existing = merged[k] {
                // Если уже есть из семантики — поднимаем score
                var boosted = existing
                let combined = min(existing.score * 0.7 + result.score * 0.3, 1.0)
                merged[k] = SearchResult(
                    type: boosted.type,
                    title: boosted.title,
                    snippet: boosted.snippet.isEmpty ? result.snippet : boosted.snippet,
                    score: combined,
                    chapter: boosted.chapter,
                    character: boosted.character,
                    worldResource: result.worldResource,
                    worldConcept: result.worldConcept,
                    worldStructure: result.worldStructure,
                    worldMetaphysics: result.worldMetaphysics,
                    timelineEvent: result.timelineEvent
                )
            } else {
                // Новый тип из keyword (мироустройство, таймлайн)
                merged[k] = result
            }
        }

        return merged.values.sorted { $0.score > $1.score }
    }

    // MARK: - Keyword Scoring

    /// Возвращает (score, snippet) если хотя бы один термин найден
    private func keywordScore(terms: [String], in fields: [String], fullText: String) -> (Float, String)? {
        let lowerFields = fields.map { $0.lowercased() }
        let lowerFull   = fullText.lowercased()

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

        // Нормализуем score: чем больше совпадений — тем выше
        let maxPossible = Float(terms.count) * Float(fields.count) * 2.0
        let score = min(totalWeight / maxPossible + 0.3, 0.99)

        return (score, bestSnippet)
    }

    // MARK: - Embedding

    private func embed(text: String) -> [Float]? {
        guard let model else { return nil }
        let tokens = tokenize(text: text)
        guard !tokens.inputIDs.isEmpty else { return nil }
        guard let inputIDs = makeMultiArray(tokens.inputIDs),
              let attnMask = makeMultiArray(tokens.attentionMask) else { return nil }
        let input = float16_modelInput(input_ids: inputIDs, attention_mask: attnMask)
        guard let output = try? model.prediction(input: input) else { return nil }
        return meanPool(output.last_hidden_state, mask: tokens.attentionMask)
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
            ids.append(contentsOf: wordPiece(word: word))
            if ids.count >= maxLength - 1 { break }
        }
        ids.append(sepToken)

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
        for (i, v) in values.enumerated() { arr[i] = NSNumber(value: Int32(v)) }
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
