import Foundation

/// Analyzes user history to extract high-frequency terms and generate pronunciation training materials.
/// Scans recent history entries, tokenizes corrected text, ranks by frequency,
/// and builds training sentences that contain multiple high-frequency terms.
@MainActor
final class TrainingMaterialGenerator: ObservableObject {
    @Published var trainingCards: [TrainingCard] = []
    @Published var topTerms: [TermFrequency] = []

    private let historyManager: HistoryManager
    private let vocabManager: VocabManager

    /// Terms the user has already mastered (passed training 3+ times)
    private var masteredTerms: Set<String> = []
    private let masteredPath: URL

    init(historyManager: HistoryManager = .shared) {
        self.historyManager = historyManager
        self.vocabManager = VocabManager()

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.masteredPath = appSupport
            .appendingPathComponent("AzexSpeech/mastered-terms.json")

        loadMastered()
    }

    /// Scan recent history (last 7 days) and generate training materials.
    func generate() {
        vocabManager.loadAll()

        // 1. Collect all corrected text from recent history
        let allDates = historyManager.allDates()
        let recentDates = Array(allDates.prefix(7))

        var allText: [String] = []
        for dateStr in recentDates {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: dateStr) {
                let entries = historyManager.loadDate(date)
                allText.append(contentsOf: entries.map { $0.corrected })
            }
        }

        // Also include today's entries already loaded
        allText.append(contentsOf: historyManager.entries.map { $0.corrected })

        // 2. Tokenize and count term frequencies
        var freqMap: [String: Int] = [:]
        let domainTerms = collectDomainTerms()

        for text in allText {
            let found = extractDomainTerms(from: text, knownTerms: domainTerms)
            for term in found {
                freqMap[term, default: 0] += 1
            }
        }

        // 3. Rank by frequency, filter out mastered terms
        let ranked = freqMap
            .map { TermFrequency(term: $0.key, count: $0.value) }
            .filter { !masteredTerms.contains($0.term) }
            .sorted { $0.count > $1.count }

        topTerms = Array(ranked.prefix(30))

        // 4. Generate training cards from top terms
        trainingCards = generateCards(from: topTerms)
    }

    /// Mark a term as mastered after user passes training.
    func markMastered(_ term: String) {
        masteredTerms.insert(term)
        saveMastered()

        // Remove from current lists
        topTerms.removeAll { $0.term == term }
        trainingCards = generateCards(from: topTerms)
    }

    /// Reset all mastered terms (re-enable all for training).
    func resetMastered() {
        masteredTerms.removeAll()
        saveMastered()
    }

    // MARK: - Private

    /// Collect all known domain terms from vocab files (the "correct" values).
    private func collectDomainTerms() -> Set<String> {
        var terms = Set<String>()

        // Collect all correction targets (the correct forms)
        for (_, value) in vocabManager.domainAIVocab.corrections {
            terms.insert(value)
        }
        for (_, value) in vocabManager.domainCryptoVocab.corrections {
            terms.insert(value)
        }
        for (_, value) in vocabManager.personalVocab.corrections {
            terms.insert(value)
        }

        return terms
    }

    /// Find which domain terms appear in a text string.
    private func extractDomainTerms(from text: String, knownTerms: Set<String>) -> [String] {
        var found: [String] = []
        let lowered = text.lowercased()

        for term in knownTerms {
            // Skip very short terms (1-2 chars) to avoid false positives
            guard term.count >= 2 else { continue }

            if lowered.contains(term.lowercased()) {
                found.append(term)
            }
        }

        return found
    }

    /// Generate training cards — each card contains a sentence with 2-4 target terms.
    private func generateCards(from terms: [TermFrequency]) -> [TrainingCard] {
        let termsToTrain = Array(terms.prefix(20))
        guard !termsToTrain.isEmpty else { return [] }

        var cards: [TrainingCard] = []

        // Group terms into cards of 2-4
        var i = 0
        while i < termsToTrain.count {
            let batchEnd = min(i + 3, termsToTrain.count)
            let batch = Array(termsToTrain[i..<batchEnd])
            let termNames = batch.map { $0.term }

            let sentence = buildTrainingSentence(terms: termNames)
            cards.append(TrainingCard(
                id: UUID().uuidString,
                terms: termNames,
                sentence: sentence,
                passCount: 0
            ))

            i = batchEnd
        }

        return cards
    }

    /// Build a natural-sounding Chinese sentence that contains the given terms.
    private func buildTrainingSentence(terms: [String]) -> String {
        // Templates with placeholders — mix Chinese context with English terms
        let templates: [[String]] = [
            ["我们用", "来搭建", "的服务"],
            ["这个项目基于", "和", "实现了核心功能"],
            ["今天在", "上看到了关于", "的最新动态"],
            ["团队决定把", "迁移到", "架构上"],
            ["最近", "的生态发展很快，特别是", "领域"],
            ["我正在用", "开发一个涉及", "的新功能"],
            ["关于", "和", "的集成方案需要讨论一下"],
            ["把", "的数据通过", "同步过去"],
        ]

        if terms.count == 1 {
            let t = terms[0]
            let singles = [
                "我们来讨论一下\(t)的使用场景",
                "这次需要在\(t)上做一些优化",
                "关于\(t)的最新版本有什么变化",
                "请帮我看一下\(t)的文档",
                "\(t)的性能表现怎么样",
            ]
            return singles[abs(t.hashValue) % singles.count]
        }

        if terms.count == 2 {
            let template = templates[abs(terms[0].hashValue) % templates.count]
            if template.count == 3 {
                return template[0] + terms[0] + template[1] + terms[1] + template[2]
            }
            return "我们用\(terms[0])和\(terms[1])来实现这个功能"
        }

        // 3+ terms
        let parts = terms.dropLast().map { String($0) }.joined(separator: "、")
        let last = terms.last!
        return "这个方案涉及\(parts)和\(last)的协同工作"
    }

    // MARK: - Persistence

    private func loadMastered() {
        guard let data = try? Data(contentsOf: masteredPath),
              let terms = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return
        }
        masteredTerms = terms
    }

    private func saveMastered() {
        guard let data = try? JSONEncoder().encode(masteredTerms) else { return }
        try? data.write(to: masteredPath, options: .atomic)
    }
}

// MARK: - Data Types

struct TermFrequency: Identifiable {
    var id: String { term }
    let term: String
    let count: Int
}

struct TrainingCard: Identifiable {
    let id: String
    let terms: [String]
    let sentence: String
    var passCount: Int

    /// Needs 3 passes to be considered mastered.
    var isMastered: Bool { passCount >= 3 }
}
