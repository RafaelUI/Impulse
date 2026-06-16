import Foundation
import CoreML
import Combine
import NaturalLanguage
import Tokenizers

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

// MARK: - Chunking

/// A text chunk produced by sentence-aware chunking. Carries its position within the parent.
struct ChunkWithParent {
    let chunkText: String
    let chunkIndex: Int
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

    private var model: MLModel?
    private var tokenizer: Tokenizer?

    /// Tunable cutoff. The current model is trained on ultrahard negatives, so it is
    /// very sharp (one strong match, everything else far below). Recalibrate after
    /// retraining on easy+hard negatives. Centralized here = one-line change.
    static let semanticThreshold: Float = 0.2
    private let seqLen   = 600                       // CoreML input is fixed [1,600]
    private let padToken = 0                         // <pad>
    private let eosToken = 1                         // <eos> — last-token pooling target
    private let bosToken = 2                         // <bos>
    private let queryPrefix = "Instruct: Retrieve semantically similar text\nQuery: "

    @Published var isReady = false
    @Published var isSearching = false

    private init() {
        Task { await load() }
    }

    private func load() async {
        let loadedMLModel: MLModel? = await Task.detached(priority: .background) {
            guard let url = Bundle.main.url(forResource: "harrier_literary", withExtension: "mlmodelc")
                         ?? Bundle.main.url(forResource: "harrier_literary", withExtension: "mlpackage") else {
                print("🔎HARRIER load: model NOT FOUND in bundle")
                return nil
            }
            print("🔎HARRIER load: model url = \(url.lastPathComponent)")
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            do { return try MLModel(contentsOf: url, configuration: config) }
            catch { print("🔎HARRIER load: MLModel init error = \(error)"); return nil }
        }.value
        let loadedModel: MLModel? = loadedMLModel

        var loadedTokenizer: Tokenizer?
                do {
                    guard let cfgURL  = Bundle.main.url(forResource: "harrier_tokenizer_config", withExtension: "json"),
                          let dataURL = Bundle.main.url(forResource: "harrier_tokenizer", withExtension: "json") else {
                        print("🔎HARRIER load: tokenizer json NOT FOUND (проверь Copy Bundle Resources, не Compile Sources)")
                        throw CocoaError(.fileNoSuchFile)
                    }
                    // Переиспользуем рабочий from(modelFolder:): складываем оба файла во временную
                    // папку под именами, которые он ждёт.
                    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("HarrierTok", isDirectory: true)
                    try? FileManager.default.removeItem(at: dir)
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: cfgURL,  to: dir.appendingPathComponent("tokenizer_config.json"))
                    try FileManager.default.copyItem(at: dataURL, to: dir.appendingPathComponent("tokenizer.json"))
                    loadedTokenizer = try await AutoTokenizer.from(modelFolder: dir)
                    print("🔎HARRIER load: tokenizer loaded via staged folder")
                } catch {
                    print("🔎HARRIER load: tokenizer error = \(error)")
                }

        self.model = loadedModel
        self.tokenizer = loadedTokenizer
        self.isReady = (loadedModel != nil && loadedTokenizer != nil)
        print("🔎HARRIER load done: model=\(loadedModel != nil) tokenizer=\(loadedTokenizer != nil) isReady=\(self.isReady)")

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

    // MARK: - Semantic Chapter Search

    func semanticChapterSearch(
        query: String,
        chapters: [Chapter],
        threshold: Float = EmbeddingService.semanticThreshold,
        onResult: @escaping (SearchResult) -> Void
    ) async {
        guard isReady else { return }
        guard let queryEmbedding = embed(text: query, isQuery: true) else { print("🔎HARRIER query embed FAILED (isReady=\(isReady))"); return }

        for chapter in chapters {
            guard !chapter.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let fullText = [chapter.title, chapter.text].filter { !$0.isEmpty }.joined(separator: " ")
            guard !fullText.isEmpty else { continue }

            // Sentence-aware chunking with overlap
            let chunks = chunkText(fullText)
            guard !chunks.isEmpty else { continue }

            var bestScore: Float = 0
            var bestChunkText = ""

            for chunk in chunks {
                guard let chunkEmb = embed(text: chunk.chunkText) else { continue }
                let score = cosineSimilarity(queryEmbedding, chunkEmb)
                if score > bestScore {
                    bestScore = score
                    bestChunkText = chunk.chunkText
                }
            }

            print("🔎HARRIER bestScore=\(bestScore) (threshold \(threshold))")
            if bestScore > threshold {
                // Small-to-Big: matched via chunk, return parent chapter; chunk text is the snippet
                onResult(SearchResult(
                    type: .chapter,
                    title: chapter.title.isEmpty ? "Без названия" : chapter.title,
                    snippet: String(bestChunkText.prefix(150)),
                    score: bestScore,
                    chapter: chapter
                ))
            }

            await Task.yield()
        }
    }

    // MARK: - Semantic Scene Search

    func semanticSceneSearch(
        query: String,
        scenes: [ScreenScene],
        threshold: Float = EmbeddingService.semanticThreshold,
        onResult: @escaping (SearchResult) -> Void
    ) async {
        guard isReady else { return }
        guard let queryEmbedding = embed(text: query, isQuery: true) else { print("🔎HARRIER query embed FAILED (isReady=\(isReady))"); return }

        for scene in scenes {
            let variationTexts = scene.variations.map { $0.text }.filter { !$0.isEmpty }
            let fullText = ([scene.title] + variationTexts).filter { !$0.isEmpty }.joined(separator: " ")
            guard !fullText.isEmpty else { continue }

            let chunks = chunkText(fullText)
            guard !chunks.isEmpty else { continue }

            var bestScore: Float = 0
            var bestChunkText = ""

            for chunk in chunks {
                guard let chunkEmb = embed(text: chunk.chunkText) else { continue }
                let score = cosineSimilarity(queryEmbedding, chunkEmb)
                if score > bestScore {
                    bestScore = score
                    bestChunkText = chunk.chunkText
                }
            }

            print("🔎HARRIER bestScore=\(bestScore) (threshold \(threshold))")
            if bestScore > threshold {
                // Small-to-Big: matched via chunk, return parent scene
                onResult(SearchResult(
                    type: .scene,
                    title: scene.title.isEmpty ? "Без названия" : scene.title,
                    snippet: String(bestChunkText.prefix(150)),
                    score: bestScore,
                    scene: scene
                ))
            }

            await Task.yield()
        }
    }

    // MARK: - Semantic Search (главы + персонажи)

    func semanticSearch(query: String, in project: WritingProject) async -> [SearchResult] {
        guard isReady else { return [] }
        guard let queryEmbedding = embed(text: query, isQuery: true) else { return [] }

        var results: [SearchResult] = []

        for chapter in project.chapters ?? [] {
            let text = [chapter.title, chapter.text].filter { !$0.isEmpty }.joined(separator: " ")
            guard !text.isEmpty else { continue }

            let chunks = chunkText(text)
            var bestScore: Float = 0
            var bestChunkText = ""
            for chunk in chunks {
                guard let emb = embed(text: chunk.chunkText) else { continue }
                let score = cosineSimilarity(queryEmbedding, emb)
                if score > bestScore { bestScore = score; bestChunkText = chunk.chunkText }
            }

            if bestScore > EmbeddingService.semanticThreshold {
                results.append(SearchResult(
                    type: .chapter,
                    title: chapter.title.isEmpty ? "Без названия" : chapter.title,
                    snippet: String(bestChunkText.prefix(150)),
                    score: bestScore,
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
            if score > EmbeddingService.semanticThreshold {
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

    // MARK: - Sentence-Aware Chunking with Overlap

    /// Public API: splits `text` into sentence-aware chunks with ~30-token overlap between neighbors.
    func chunkText(_ text: String) -> [ChunkWithParent] {
        chunkBySentences(text)
    }

    private func chunkBySentences(
        _ text: String,
        maxContentTokens: Int = 480,
        overlapBudget: Int = 64
    ) -> [ChunkWithParent] {
        let nlTokenizer = NLTokenizer(unit: .sentence)
        nlTokenizer.string = text

        var sentences: [String] = []
        nlTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let s = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { sentences.append(s) }
            return true
        }

        guard !sentences.isEmpty else {
            return text.isEmpty ? [] : [ChunkWithParent(chunkText: text, chunkIndex: 0)]
        }

        var result: [ChunkWithParent] = []
        var windowSentences: [String] = []
        var windowTokens = 0

        for sentence in sentences {
            let st = tokenCount(sentence)

            if windowTokens + st > maxContentTokens, !windowSentences.isEmpty {
                // Flush the current window
                result.append(ChunkWithParent(
                    chunkText: windowSentences.joined(separator: " "),
                    chunkIndex: result.count
                ))
                // Build overlap: take trailing sentences up to overlapBudget tokens
                var overlap: [String] = []
                var overlapTokens = 0
                for s in windowSentences.reversed() {
                    let t = tokenCount(s)
                    guard overlapTokens + t <= overlapBudget else { break }
                    overlap.insert(s, at: 0)
                    overlapTokens += t
                }
                windowSentences = overlap
                windowTokens = overlapTokens
            }

            windowSentences.append(sentence)
            windowTokens += st
        }

        if !windowSentences.isEmpty {
            result.append(ChunkWithParent(
                chunkText: windowSentences.joined(separator: " "),
                chunkIndex: result.count
            ))
        }

        return result
    }

    /// Token count for chunk-sizing purposes — uses the real Gemma tokenizer.
    private func tokenCount(_ text: String) -> Int {
        tokenizer?.encode(text: text).count ?? text.split(whereSeparator: { $0.isWhitespace }).count
    }

    // MARK: - Embedding

    private func embed(text: String, isQuery: Bool = false) -> [Float]? {
        guard let model, let tokenizer else { print("🔎HARRIER embed: model/tokenizer nil"); return nil }
        let prepared = isQuery ? (queryPrefix + text) : text
        var ids = tokenizer.encode(text: prepared)          // adds <bos> … <eos>
        guard !ids.isEmpty else { return nil }
        // Truncate but keep the trailing <eos> (the pooled position)
        if ids.count > seqLen { ids = Array(ids.prefix(seqLen - 1)) + [eosToken] }
        // LEFT padding: the model pools the FIXED last index, so real text must end at seqLen-1
        let padCount = seqLen - ids.count
        let inputIDs = [Int](repeating: padToken, count: padCount) + ids
        let mask     = [Int](repeating: 0, count: padCount) + [Int](repeating: 1, count: ids.count)
        guard let idsArr = makeMultiArray(inputIDs), let maskArr = makeMultiArray(mask) else {
            print("🔎HARRIER embed: makeMultiArray failed"); return nil
        }
        do {
            let provider = try MLDictionaryFeatureProvider(
                dictionary: ["input_ids": idsArr, "attention_mask": maskArr])
            let output = try model.prediction(from: provider)
            guard let emb = output.featureValue(for: "embedding")?.multiArrayValue else {
                print("🔎HARRIER embed: no 'embedding' output feature"); return nil
            }
            var result = [Float](repeating: 0, count: emb.count)
            for i in 0..<emb.count { result[i] = emb[i].floatValue }
            return result
        } catch {
            print("🔎HARRIER embed PREDICTION ERROR: \(error)")
            return nil
        }
    }
    // MARK: - CoreML input helper

    private func makeMultiArray(_ values: [Int]) -> MLMultiArray? {
        guard let arr = try? MLMultiArray(shape: [1, NSNumber(value: seqLen)], dataType: .int32) else { return nil }
        for (i, v) in values.prefix(seqLen).enumerated() { arr[i] = NSNumber(value: Int32(v)) }
        return arr
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
