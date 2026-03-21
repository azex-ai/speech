import Foundation

/// Corrects ASR output using vocab files + local small model.
/// Phase 1: Rule-based replacement from vocab files
/// Phase 2: Local small LLM (MLX Qwen2.5-0.5B) for context-aware correction
final class CorrectionEngine {
    private let vocabManager: VocabManager

    init(vocabManager: VocabManager) {
        self.vocabManager = vocabManager
    }

    /// Correct ASR output text using all available vocab layers
    func correct(_ asrText: String) -> String {
        // Phase 1: Rule-based replacement
        var result = asrText
        let corrections = vocabManager.allCorrections()

        // Sort by key length descending (match longer phrases first)
        let sortedKeys = corrections.keys.sorted { $0.count > $1.count }

        for key in sortedKeys {
            guard let replacement = corrections[key] else { continue }
            result = result.replacingOccurrences(
                of: key,
                with: replacement,
                options: .caseInsensitive
            )
        }

        // Add punctuation if missing
        result = addPunctuation(result)

        return result
    }

    /// Add basic punctuation to ASR output that typically has none.
    /// - Ensures text ends with a period (。)
    /// - Future: mid-sentence comma insertion based on clause boundaries
    private func addPunctuation(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return result }

        // If text already ends with punctuation, leave it
        let lastChar = result.last!
        let endPunctuation: Set<Character> = ["。", "！", "？", "，", ".", "!", "?", ",", "；", ";"]
        if !endPunctuation.contains(lastChar) {
            // Add period at end of each session
            result += "。"
        }

        return result
    }

    /// Extract corrections by diffing original ASR output with user-edited text
    func extractCorrections(original: String, edited: String) -> [(String, String)] {
        let origWords = tokenize(original)
        let editWords = tokenize(edited)

        guard origWords.count > 0, editWords.count > 0 else { return [] }

        // Skip if >50% words changed (full rewrite, not correction)
        let unchangedCount = origWords.filter { editWords.contains($0) }.count
        let changeRatio = 1.0 - (Double(unchangedCount) / Double(max(origWords.count, editWords.count)))
        if changeRatio > 0.5 { return [] }

        // Simple substitution detection via aligned pairs
        // TODO: Use LCS diff (reference: OpenWhispr correctionLearner.js)
        var corrections: [(String, String)] = []
        let minLen = min(origWords.count, editWords.count)

        for i in 0..<minLen {
            if origWords[i] != editWords[i] {
                let orig = origWords[i]
                let edit = editWords[i]

                // Skip if too short
                guard edit.count >= 2 else { continue }

                // Skip if edit distance ratio too high (unrelated words)
                let dist = levenshteinDistance(orig, edit)
                let maxLen = max(orig.count, edit.count)
                if maxLen > 0 && Double(dist) / Double(maxLen) > 0.65 { continue }

                corrections.append((orig, edit))
            }
        }

        return corrections
    }

    // MARK: - Private

    private func tokenize(_ text: String) -> [String] {
        text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        var dp = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)

        for i in 0...a.count { dp[i][0] = i }
        for j in 0...b.count { dp[0][j] = j }

        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
                }
            }
        }
        return dp[a.count][b.count]
    }
}
