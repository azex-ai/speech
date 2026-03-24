import Foundation

/// Corrects ASR output using vocab files + fuzzy matching.
///
/// Three-pass correction pipeline:
/// 1. Exact substring match (longest key first, case-insensitive)
/// 2. Fuzzy token match (edit distance ≤ 40% of key length, for English tokens)
/// 3. Fuzzy multi-token match (combine consecutive tokens, match against multi-word keys)
final class CorrectionEngine {
    private let vocabManager: VocabManager

    /// Fuzzy match threshold: max edit distance ratio (0.0 = exact, 1.0 = anything matches)
    private let fuzzyThreshold: Double = 0.45

    init(vocabManager: VocabManager) {
        self.vocabManager = vocabManager
    }

    /// Correct ASR output text using all available vocab layers
    func correct(_ asrText: String) -> String {
        let corrections = vocabManager.allCorrections()
        guard !corrections.isEmpty else { return addPunctuation(asrText) }

        // Pass 0: Collapse spaced-out uppercase letters (e.g. "U S D C" → "USDC")
        var result = collapseSpacedLetters(asrText)

        // Pass 1: Exact substring replacement (longest key first)
        result = exactMatch(result, corrections: corrections)

        // Pass 2+3: Fuzzy token-level matching for remaining English words
        result = fuzzyTokenMatch(result, corrections: corrections)

        return addPunctuation(result)
    }

    // MARK: - Pass 0: Collapse Spaced Letters

    /// ASR sometimes outputs individual letters separated by spaces, e.g.
    /// "U S D C" instead of "USDC", or "E T H" instead of "ETH".
    /// This pass merges consecutive single ASCII letters back into words.
    /// It also handles mixed cases like "B i t c o i n" → "Bitcoin".
    private func collapseSpacedLetters(_ text: String) -> String {
        // Split by spaces, find runs of single ASCII letters, merge them
        let parts = text.components(separatedBy: " ")
        var result: [String] = []
        var letterRun: [String] = []

        func flushLetterRun() {
            guard !letterRun.isEmpty else { return }
            if letterRun.count >= 2 {
                // Strip trailing punctuation from each letter, merge, then re-append
                // e.g. ["U","S","D","T。"] → "USDT" + "。"
                var trailing = ""
                let lastItem = letterRun.last!
                let lastCore = lastItem.trimmingCharacters(in: .punctuationCharacters)
                if lastCore.count < lastItem.count {
                    trailing = String(lastItem.dropFirst(lastCore.count))
                }
                let merged = letterRun.map { $0.trimmingCharacters(in: .punctuationCharacters) }.joined()
                result.append(merged + trailing)
            } else {
                result.append(letterRun[0])
            }
            letterRun = []
        }

        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            let core = trimmed.trimmingCharacters(in: .punctuationCharacters)
            if core.count == 1, let ch = core.first, ch.isASCII, ch.isLetter {
                letterRun.append(trimmed)
            } else {
                flushLetterRun()
                result.append(part)
            }
        }
        flushLetterRun()

        return result.joined(separator: " ")
    }

    // MARK: - Pass 1: Exact Match

    /// Replace exact substring matches, longest key first, case-insensitive.
    /// Optimized: only scan keys that could plausibly appear in the text (length filter + early exit).
    private func exactMatch(_ text: String, corrections: [String: String]) -> String {
        var result = text
        let textLen = result.count
        let sortedKeys = corrections.keys.sorted { $0.count > $1.count }

        for key in sortedKeys {
            // Skip keys longer than the remaining text
            guard key.count <= textLen else { continue }
            guard let replacement = corrections[key] else { continue }
            // Only call replacingOccurrences if the key could exist (case-insensitive range check)
            if result.range(of: key, options: .caseInsensitive) != nil {
                result = result.replacingOccurrences(
                    of: key,
                    with: replacement,
                    options: .caseInsensitive
                )
            }
        }
        return result
    }

    // MARK: - Pass 2+3: Fuzzy Token Match

    /// Split text into tokens, try fuzzy matching unrecognized English tokens
    /// against vocab keys. Also tries combining consecutive tokens for multi-word terms.
    private func fuzzyTokenMatch(_ text: String, corrections: [String: String]) -> String {
        // Build lookup: lowercase key → (original key, replacement)
        // Only include keys that look like English (contain ASCII letters)
        var englishKeys: [(key: String, replacement: String)] = []
        for (k, v) in corrections {
            if k.contains(where: { $0.isASCII && $0.isLetter }) {
                englishKeys.append((key: k.lowercased(), replacement: v))
            }
        }
        guard !englishKeys.isEmpty else { return text }

        // Sort by key length descending for multi-word priority
        englishKeys.sort { $0.key.count > $1.key.count }

        // Split into segments: Chinese text vs English tokens (separated by spaces)
        let segments = splitSegments(text)
        var result: [String] = []
        var i = 0

        while i < segments.count {
            let seg = segments[i]

            // Only try fuzzy match on English-looking tokens
            if isEnglishToken(seg) {
                // Try combining 2-3 consecutive English tokens for multi-word match
                var matched = false

                for windowSize in stride(from: min(3, segments.count - i), through: 1, by: -1) {
                    // Collect consecutive English tokens
                    var tokens: [String] = []
                    var j = i
                    while tokens.count < windowSize && j < segments.count {
                        if isEnglishToken(segments[j]) {
                            tokens.append(segments[j])
                            j += 1
                        } else if segments[j].trimmingCharacters(in: .whitespaces).isEmpty {
                            j += 1 // skip whitespace between tokens
                        } else {
                            break
                        }
                    }
                    guard tokens.count == windowSize else { continue }

                    let combined = tokens.joined(separator: " ").lowercased()

                    // Try fuzzy match against vocab keys
                    if let match = findFuzzyMatch(combined, in: englishKeys) {
                        result.append(match.replacement)
                        i = j // skip all consumed segments
                        matched = true
                        break
                    }
                }

                if !matched {
                    result.append(seg)
                    i += 1
                }
            } else {
                result.append(seg)
                i += 1
            }
        }

        return result.joined()
    }

    /// Find best fuzzy match for a query string among vocab keys.
    /// Returns nil if no match within threshold.
    private func findFuzzyMatch(_ query: String, in keys: [(key: String, replacement: String)]) -> (key: String, replacement: String)? {
        let queryLen = query.count
        guard queryLen >= 3 else { return nil } // skip very short tokens

        var bestMatch: (key: String, replacement: String)?
        var bestScore: Double = 1.0 // lower is better (edit distance ratio)

        for entry in keys {
            let keyLen = entry.key.count
            // Skip keys that are too different in length
            let lenRatio = Double(abs(keyLen - queryLen)) / Double(max(keyLen, queryLen))
            if lenRatio > 0.5 { continue }

            let dist = levenshteinDistance(query, entry.key)
            let maxLen = max(queryLen, keyLen)
            let score = Double(dist) / Double(maxLen)

            if score < bestScore && score <= fuzzyThreshold {
                bestScore = score
                bestMatch = entry
            }
        }

        return bestMatch
    }

    // MARK: - Text Segmentation

    /// Split text into segments preserving Chinese characters, English words, and whitespace.
    /// e.g., "啊CLOUD COLD测试" → ["啊", "CLOUD", " ", "COLD", "测试"]
    private func splitSegments(_ text: String) -> [String] {
        var segments: [String] = []
        var current = ""
        var currentType: SegmentType = .other

        for char in text {
            let charType = segmentType(char)
            if charType != currentType && !current.isEmpty {
                segments.append(current)
                current = ""
            }
            current.append(char)
            currentType = charType
        }
        if !current.isEmpty {
            segments.append(current)
        }
        return segments
    }

    private enum SegmentType {
        case english, chinese, whitespace, other
    }

    private func segmentType(_ char: Character) -> SegmentType {
        if char.isASCII && char.isLetter { return .english }
        if char.isWhitespace { return .whitespace }
        if char.unicodeScalars.first.map({ $0.value >= 0x4E00 && $0.value <= 0x9FFF }) == true { return .chinese }
        return .other
    }

    private func isEnglishToken(_ s: String) -> Bool {
        !s.isEmpty && s.first?.isASCII == true && s.first?.isLetter == true
    }

    // MARK: - Punctuation

    private func addPunctuation(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return result }

        let lastChar = result.last!
        let endPunctuation: Set<Character> = ["。", "！", "？", "，", ".", "!", "?", ",", "；", ";"]
        if !endPunctuation.contains(lastChar) {
            result += "。"
        }
        return result
    }

    // MARK: - Diff / Learning

    /// Extract corrections by diffing original ASR output with user-edited text
    func extractCorrections(original: String, edited: String) -> [(String, String)] {
        let origWords = tokenize(original)
        let editWords = tokenize(edited)

        guard origWords.count > 0, editWords.count > 0 else { return [] }

        let unchangedCount = origWords.filter { editWords.contains($0) }.count
        let changeRatio = 1.0 - (Double(unchangedCount) / Double(max(origWords.count, editWords.count)))
        if changeRatio > 0.5 { return [] }

        var corrections: [(String, String)] = []
        let minLen = min(origWords.count, editWords.count)

        for i in 0..<minLen {
            if origWords[i] != editWords[i] {
                let orig = origWords[i]
                let edit = editWords[i]
                guard edit.count >= 2 else { continue }

                let dist = levenshteinDistance(orig, edit)
                let maxLen = max(orig.count, edit.count)
                if maxLen > 0 && Double(dist) / Double(maxLen) > 0.65 { continue }

                corrections.append((orig, edit))
            }
        }
        return corrections
    }

    // MARK: - Utilities

    private func tokenize(_ text: String) -> [String] {
        text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }

    func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
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
