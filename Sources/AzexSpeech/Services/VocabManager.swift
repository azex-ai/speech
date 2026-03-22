import Foundation

/// Manages all vocabulary files: personal + domain + context
extension Notification.Name {
    static let vocabDidUpdate = Notification.Name("vocabDidUpdate")
}

final class VocabManager {
    private(set) var personalVocab: VocabFile = VocabFile()
    private(set) var domainCryptoVocab: VocabFile = VocabFile()
    private(set) var domainAIVocab: VocabFile = VocabFile()
    private(set) var contextWords: [String: String] = [:]

    private let appSupportDir: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.appSupportDir = base.appendingPathComponent("AzexSpeech", isDirectory: true)
    }

    /// Load all vocab files
    func loadAll() {
        ensureAppSupportDir()
        print("📚 VocabManager: appSupportDir = \(appSupportDir.path)")
        print("📚 VocabManager: dir exists = \(FileManager.default.fileExists(atPath: appSupportDir.path))")
        copyBundledVocabIfNeeded()

        personalVocab = loadVocab(from: appSupportDir.appendingPathComponent("my-vocab.json"))
        domainCryptoVocab = loadVocab(from: appSupportDir.appendingPathComponent("domain-crypto.json"))
        domainAIVocab = loadVocab(from: appSupportDir.appendingPathComponent("domain-ai.json"))
    }

    /// Get merged corrections map (personal > domain)
    func allCorrections() -> [String: String] {
        var merged: [String: String] = [:]

        // Layer 3: Domain vocab (lowest priority)
        for (k, v) in domainCryptoVocab.corrections { merged[k] = v }
        for (k, v) in domainAIVocab.corrections { merged[k] = v }

        // Layer 2: Context words
        for (k, v) in contextWords { merged[k] = v }

        // Layer 1: Personal vocab (highest priority, overwrites)
        for (k, v) in personalVocab.corrections { merged[k] = v }

        return merged
    }

    /// Add a correction from user edit behavior
    func learnCorrection(original: String, corrected: String) {
        personalVocab.corrections[original] = corrected
        savePersonalVocab()
        // Notify other VocabManager instances to reload
        NotificationCenter.default.post(name: .vocabDidUpdate, object: nil)
    }

    /// Update context words from active window
    func updateContextWords(_ words: [String: String]) {
        contextWords = words
    }

    /// Generate initial personal vocab from calibration
    func generateFromCalibration(asrOutput: String, expectedText: String) {
        let asrWords = asrOutput.components(separatedBy: .whitespaces)
        let expectedWords = expectedText.components(separatedBy: .whitespaces)

        // Simple word-level diff — find substitutions
        // TODO: Use LCS diff algorithm (reference: OpenWhispr correctionLearner.js)
        let pairs = zip(asrWords, expectedWords)
        for (asr, expected) in pairs where asr != expected {
            personalVocab.corrections[asr] = expected
        }

        personalVocab.calibratedAt = ISO8601DateFormatter().string(from: Date())
        savePersonalVocab()
    }

    // MARK: - Private

    private func ensureAppSupportDir() {
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
    }

    private func copyBundledVocabIfNeeded() {
        let fm = FileManager.default

        for name in ["domain-ai", "domain-crypto"] {
            let dest = appSupportDir.appendingPathComponent("\(name).json")
            if !fm.fileExists(atPath: dest.path) {
                if let bundled = Bundle.module.url(forResource: name, withExtension: "json") {
                    do {
                        try fm.copyItem(at: bundled, to: dest)
                        print("📚 Copied \(name).json to app support")
                    } catch {
                        print("📚 Failed to copy \(name).json: \(error)")
                    }
                } else {
                    print("📚 Bundle.module has no \(name).json")
                }
            }
        }

        // Create empty personal vocab if not exists
        let personalPath = appSupportDir.appendingPathComponent("my-vocab.json")
        if !fm.fileExists(atPath: personalPath.path) {
            let empty = VocabFile()
            if let data = try? JSONEncoder().encode(empty) {
                try? data.write(to: personalPath)
            }
        }
    }

    private func loadVocab(from url: URL) -> VocabFile {
        guard let data = try? Data(contentsOf: url),
              let vocab = try? JSONDecoder().decode(VocabFile.self, from: data) else {
            return VocabFile()
        }
        return vocab
    }

    private func savePersonalVocab() {
        let path = appSupportDir.appendingPathComponent("my-vocab.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(personalVocab) {
            try? data.write(to: path, options: .atomic)
        }
    }
}
