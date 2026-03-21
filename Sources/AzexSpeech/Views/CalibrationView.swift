import SwiftUI

struct CalibrationView: View {
    enum Phase {
        case ready
        case reading
        case processing
        case report
    }

    @State private var phase: Phase = .ready
    @State private var calibrationText: String = ""
    @StateObject private var engine = CalibrationEngine()
    @State private var result: CalibrationResult?
    @State private var paragraphs: [String] = []
    @State private var paragraphIndex: Int = 0
    /// Tracks which paragraph indices have been calibrated (completed)
    @State private var completedIndices: Set<Int> = []

    var body: some View {
        VStack(spacing: 0) {
            switch phase {
            case .ready:
                readyPhase
            case .reading:
                readingPhase
            case .processing:
                processingPhase
            case .report:
                reportPhase
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AzexTheme.bg)
        .onAppear {
            engine.prepare()
        }
    }

    // MARK: - Ready Phase (Flashcard Browser)

    private var readyPhase: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("语音校准")
                    .font(.title2.bold())
                    .foregroundStyle(AzexTheme.textPrimary)
                Spacer()
                Text("\(completedIndices.count)/\(paragraphs.count) 已完成")
                    .font(.caption)
                    .foregroundStyle(AzexTheme.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Current card with navigation
            if !paragraphs.isEmpty {
                VStack(spacing: 12) {
                    // Card
                    VStack(alignment: .leading, spacing: 12) {
                        // Card header
                        HStack {
                            Text("# \(paragraphIndex + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(AzexTheme.accent)

                            Spacer()

                            if completedIndices.contains(paragraphIndex) {
                                Label("已校准", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(AzexTheme.success)
                            } else {
                                Text("未校准")
                                    .font(.caption)
                                    .foregroundStyle(AzexTheme.textTertiary)
                            }
                        }

                        // Card text — scrollable, show full content
                        ScrollView {
                            Text(paragraphs[paragraphIndex])
                                .font(.callout)
                                .foregroundStyle(AzexTheme.textPrimary)
                                .lineSpacing(6)
                                .textSelection(.enabled)
                        }
                    }
                    .azexCard()
                    .padding(.horizontal, 20)

                    // Navigation: ← card indicator dots →
                    HStack(spacing: 16) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                paragraphIndex = (paragraphIndex - 1 + paragraphs.count) % paragraphs.count
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.body.bold())
                                .foregroundStyle(AzexTheme.textSecondary)
                        }
                        .buttonStyle(.plain)

                        // Dot indicators
                        HStack(spacing: 5) {
                            ForEach(0..<paragraphs.count, id: \.self) { i in
                                Circle()
                                    .fill(dotColor(for: i))
                                    .frame(width: i == paragraphIndex ? 8 : 6,
                                           height: i == paragraphIndex ? 8 : 6)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            paragraphIndex = i
                                        }
                                    }
                            }
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                paragraphIndex = (paragraphIndex + 1) % paragraphs.count
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.body.bold())
                                .foregroundStyle(AzexTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                // Action buttons
                VStack(spacing: 8) {
                    Button {
                        calibrationText = paragraphs[paragraphIndex]
                        phase = .reading
                    } label: {
                        Label(
                            completedIndices.contains(paragraphIndex) ? "重新朗读" : "开始朗读",
                            systemImage: completedIndices.contains(paragraphIndex) ? "arrow.counterclockwise" : "mic.fill"
                        )
                        .frame(minWidth: 160)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AzexTheme.accent)
                    .controlSize(.large)

                    Text("预计用时 15-30 秒")
                        .font(.caption)
                        .foregroundStyle(AzexTheme.textTertiary)
                }
                .padding(.bottom, 20)
            } else {
                // Loading
                Spacer()
                ProgressView()
                    .tint(AzexTheme.accent)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AzexTheme.bg)
        .onAppear {
            if paragraphs.isEmpty { loadParagraphs() }
        }
    }

    private func dotColor(for index: Int) -> Color {
        if index == paragraphIndex {
            return AzexTheme.accent
        } else if completedIndices.contains(index) {
            return AzexTheme.success
        } else {
            return AzexTheme.textTertiary
        }
    }

    // MARK: - Reading Phase

    private var readingPhase: some View {
        VStack(spacing: 20) {
            Text("请朗读以下文本")
                .font(.title3.bold())
                .foregroundStyle(AzexTheme.textPrimary)
                .padding(.top, 24)

            ScrollView {
                Text(calibrationText)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(AzexTheme.textPrimary)
                    .lineSpacing(8)
                    .padding(20)
            }
            .azexCard(padding: 0)
            .frame(maxHeight: 240)
            .padding(.horizontal, 20)

            Spacer()

            if engine.isRecording {
                HStack(spacing: 10) {
                    Circle()
                        .fill(AzexTheme.recording)
                        .frame(width: 10, height: 10)
                    Text("录音中...")
                        .font(.callout.bold())
                        .foregroundStyle(AzexTheme.recording)
                }
                .padding(.bottom, 4)

                Button {
                    engine.stopAndRecognize()
                    phase = .processing
                    waitForRecognition()
                } label: {
                    Label("停止录音", systemImage: "stop.fill")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .tint(AzexTheme.recording)
                .controlSize(.large)
            } else {
                Text("按下按钮开始朗读")
                    .font(.callout)
                    .foregroundStyle(AzexTheme.textSecondary)
                    .padding(.bottom, 4)

                Button {
                    engine.startRecording()
                } label: {
                    Label("开始录音", systemImage: "mic.fill")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .tint(AzexTheme.accent)
                .controlSize(.large)
            }

            if !engine.isReady {
                Text("ASR 模型未下载，请先在设置中下载模型")
                    .font(.caption)
                    .foregroundStyle(AzexTheme.error)
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Processing Phase

    private var processingPhase: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(AzexTheme.accent)

            Text("正在分析...")
                .font(.title3)
                .foregroundStyle(AzexTheme.textPrimary)

            Text("对比识别结果与标准文本")
                .font(.callout)
                .foregroundStyle(AzexTheme.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    // MARK: - Report Phase

    private var reportPhase: some View {
        VStack(spacing: 16) {
            Text("校准报告")
                .font(.title2.bold())
                .foregroundStyle(AzexTheme.textPrimary)
                .padding(.top, 20)

            if let result {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Correct section
                        if !result.correct.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(
                                    "识别正确 (\(result.correct.count) 个)",
                                    systemImage: "checkmark.circle.fill"
                                )
                                .font(.headline)
                                .foregroundStyle(AzexTheme.success)

                                FlowLayout(spacing: 6) {
                                    ForEach(result.correct, id: \.self) { word in
                                        Text(word)
                                            .font(.callout)
                                            .foregroundStyle(AzexTheme.textPrimary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(AzexTheme.success.opacity(0.15))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                            }
                            .azexCard()
                        }

                        // Corrections section
                        if !result.corrections.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(
                                    "需要学习 (\(result.corrections.count) 个)",
                                    systemImage: "exclamationmark.triangle.fill"
                                )
                                .font(.headline)
                                .foregroundStyle(AzexTheme.accent)

                                ForEach(
                                    Array(result.corrections.enumerated()),
                                    id: \.offset
                                ) { _, pair in
                                    HStack(spacing: 8) {
                                        Text(pair.recognized)
                                            .font(.callout)
                                            .foregroundStyle(AzexTheme.textSecondary)
                                            .strikethrough()

                                        Image(systemName: "arrow.right")
                                            .font(.caption)
                                            .foregroundStyle(AzexTheme.textTertiary)

                                        Text(pair.expected)
                                            .font(.callout.bold())
                                            .foregroundStyle(AzexTheme.accent)
                                    }
                                }
                            }
                            .azexCard()
                        }

                        // Empty state
                        if result.correct.isEmpty && result.corrections.isEmpty {
                            Text("未检测到可分析的词汇")
                                .font(.callout)
                                .foregroundStyle(AzexTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                if !result.corrections.isEmpty {
                    Text("已自动添加 \(result.corrections.count) 条纠正规则")
                        .font(.caption)
                        .foregroundStyle(AzexTheme.success)
                }
            }

            Spacer()

            HStack(spacing: 16) {
                Button {
                    // Advance to next uncompleted card
                    paragraphIndex = (paragraphIndex + 1) % paragraphs.count
                    calibrationText = paragraphs[paragraphIndex]
                    engine.recognizedText = nil
                    result = nil
                    phase = .reading
                } label: {
                    Label("下一段", systemImage: "chevron.right")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.bordered)
                .tint(AzexTheme.accent)
                .controlSize(.large)

                Button {
                    result = nil
                    phase = .ready
                } label: {
                    Text("返回卡片")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .tint(AzexTheme.accent)
                .controlSize(.large)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Logic

    private func waitForRecognition() {
        Task { @MainActor in
            // Poll for recognition result
            while engine.recognizedText == nil {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }

            let recognized = engine.recognizedText ?? ""
            let diffResult = diffTexts(expected: calibrationText, recognized: recognized)
            self.result = diffResult

            // Auto-save corrections
            if !diffResult.corrections.isEmpty {
                saveCorrections(diffResult.corrections)
            }

            completedIndices.insert(paragraphIndex)
            phase = .report
        }
    }

    private func loadParagraphs() {
        let domain = loadDomain()
        let filename: String
        switch domain {
        case "ai": filename = "calibration-ai"
        case "crypto": filename = "calibration-crypto"
        default: filename = "calibration-both"
        }
        guard let url = Bundle.module.url(forResource: filename, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            paragraphs = ["Claude Solana EigenLayer DeepSeek Uniswap"]
            return
        }
        paragraphs = text.components(separatedBy: "\n---\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        paragraphIndex = 0
    }

    private func nextParagraph() -> String {
        guard !paragraphs.isEmpty else { return "" }
        let text = paragraphs[paragraphIndex % paragraphs.count]
        paragraphIndex += 1
        return text
    }

    private func loadDomain() -> String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let path = appSupport.appendingPathComponent("AzexSpeech/onboarding-complete.json")
        guard let data = try? Data(contentsOf: path),
              let state = try? JSONDecoder().decode(OnboardingState.self, from: data)
        else {
            return "both"
        }
        return state.domain
    }

    private func diffTexts(expected: String, recognized: String) -> CalibrationResult {
        let expectedWords = expected
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let recognizedWords = recognized
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        var correct: [String] = []
        var corrections: [CorrectionPair] = []

        for expectedWord in expectedWords {
            let cleanExpected = expectedWord.trimmingCharacters(in: .punctuationCharacters)
            guard !cleanExpected.isEmpty else { continue }

            // Skip common Chinese particles and short words
            if cleanExpected.count <= 1 { continue }

            let found = recognizedWords.contains { word in
                word.trimmingCharacters(in: .punctuationCharacters)
                    .lowercased() == cleanExpected.lowercased()
            }

            if found {
                correct.append(cleanExpected)
            } else {
                // Find the closest recognized word by edit distance
                let closest = recognizedWords
                    .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                    .filter { !$0.isEmpty }
                    .min(by: { levenshtein($0, cleanExpected) < levenshtein($1, cleanExpected) })

                if let closest {
                    let distance = levenshtein(closest, cleanExpected)
                    let threshold = max(cleanExpected.count / 2, 3)
                    if distance <= threshold && distance > 0 {
                        corrections.append(CorrectionPair(
                            recognized: closest,
                            expected: cleanExpected
                        ))
                    }
                }
            }
        }

        // Deduplicate
        let uniqueCorrect = Array(Set(correct)).sorted()
        var seen = Set<String>()
        let uniqueCorrections = corrections.filter { pair in
            let key = "\(pair.recognized)->\(pair.expected)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        return CalibrationResult(correct: uniqueCorrect, corrections: uniqueCorrections)
    }

    private func levenshtein(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let m = a.count
        let n = b.count

        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }

        return matrix[m][n]
    }

    private func saveCorrections(_ corrections: [CorrectionPair]) {
        let vocabManager = VocabManager()
        vocabManager.loadAll()
        for pair in corrections {
            vocabManager.learnCorrection(original: pair.recognized, corrected: pair.expected)
        }
    }
}

// MARK: - Data Types

struct CalibrationResult {
    let correct: [String]
    let corrections: [CorrectionPair]
}

struct CorrectionPair {
    let recognized: String
    let expected: String
}

// MARK: - Flow Layout (for tag-style word display)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct ArrangeResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x)
            totalHeight = y + rowHeight
        }

        return ArrangeResult(
            size: CGSize(width: totalWidth, height: totalHeight),
            positions: positions
        )
    }
}
