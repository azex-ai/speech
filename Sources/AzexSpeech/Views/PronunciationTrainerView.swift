import SwiftUI

/// Lazy-loaded pronunciation training module.
/// Analyzes user history to find high-frequency terms,
/// generates training sentences, and provides read-aloud practice with ASR feedback.
struct PronunciationTrainerView: View {
    enum Phase {
        case loading
        case termList
        case practicing
        case result
    }

    @StateObject private var generator = TrainingMaterialGenerator()
    @StateObject private var engine = CalibrationEngine()
    @State private var phase: Phase = .loading
    @State private var currentCardIndex: Int = 0
    @State private var lastRecognized: String = ""
    @State private var matchedTerms: [String] = []
    @State private var missedTerms: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            switch phase {
            case .loading:
                loadingPhase
            case .termList:
                termListPhase
            case .practicing:
                practicingPhase
            case .result:
                resultPhase
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AzexTheme.bg)
        .onAppear {
            engine.prepare()
            generateMaterials()
        }
    }

    // MARK: - Loading

    private var loadingPhase: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(AzexTheme.accent)
            Text("正在分析你的使用历史...")
                .font(.callout)
                .foregroundStyle(AzexTheme.textSecondary)
            Spacer()
        }
    }

    // MARK: - Term List (Overview)

    private var termListPhase: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("发音训练")
                        .font(.title2.bold())
                        .foregroundStyle(AzexTheme.textPrimary)
                    Text("基于你的使用历史，为你生成个性化训练素材")
                        .font(.caption)
                        .foregroundStyle(AzexTheme.textSecondary)
                }
                Spacer()
                Button {
                    phase = .loading
                    generateMaterials()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AzexTheme.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            if generator.topTerms.isEmpty {
                // Empty state
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "text.badge.checkmark")
                        .font(.system(size: 40))
                        .foregroundStyle(AzexTheme.textTertiary)
                    Text("暂无训练数据")
                        .font(.headline)
                        .foregroundStyle(AzexTheme.textSecondary)
                    Text("多使用语音输入后，这里会自动生成训练内容")
                        .font(.caption)
                        .foregroundStyle(AzexTheme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else {
                // High-frequency terms
                VStack(alignment: .leading, spacing: 8) {
                    Text("你的高频术语 Top \(generator.topTerms.count)")
                        .font(.subheadline.bold())
                        .foregroundStyle(AzexTheme.textPrimary)

                    ScrollView {
                        FlowLayoutSimple(spacing: 6) {
                            ForEach(generator.topTerms) { term in
                                HStack(spacing: 4) {
                                    Text(term.term)
                                        .font(.callout)
                                    Text("×\(term.count)")
                                        .font(.caption2)
                                        .foregroundStyle(AzexTheme.textTertiary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(AzexTheme.accent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .foregroundStyle(AzexTheme.textPrimary)
                            }
                        }
                    }
                }
                .azexCard()
                .padding(.horizontal, 20)

                // Training cards
                if !generator.trainingCards.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("训练卡片 (\(generator.trainingCards.count) 组)")
                            .font(.subheadline.bold())
                            .foregroundStyle(AzexTheme.textPrimary)

                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(Array(generator.trainingCards.enumerated()), id: \.element.id) { index, card in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(card.sentence)
                                                .font(.callout)
                                                .foregroundStyle(AzexTheme.textPrimary)
                                                .lineLimit(2)
                                            HStack(spacing: 4) {
                                                ForEach(card.terms, id: \.self) { term in
                                                    Text(term)
                                                        .font(.caption2)
                                                        .foregroundStyle(AzexTheme.accent)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(AzexTheme.accent.opacity(0.1))
                                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                                }
                                            }
                                        }
                                        Spacer()
                                        if card.isMastered {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(AzexTheme.success)
                                        }
                                    }
                                    .padding(10)
                                    .background(AzexTheme.bgCard.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .onTapGesture {
                                        currentCardIndex = index
                                        phase = .practicing
                                    }
                                }
                            }
                        }
                    }
                    .azexCard()
                    .padding(.horizontal, 20)
                }

                Spacer()

                // Start training button
                if !generator.trainingCards.isEmpty {
                    Button {
                        currentCardIndex = 0
                        phase = .practicing
                    } label: {
                        Label("开始训练", systemImage: "mic.fill")
                            .frame(minWidth: 160)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AzexTheme.accent)
                    .controlSize(.large)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: - Practicing

    private var practicingPhase: some View {
        let card = generator.trainingCards.indices.contains(currentCardIndex)
            ? generator.trainingCards[currentCardIndex]
            : nil

        return VStack(spacing: 20) {
            // Progress
            HStack {
                Text("第 \(currentCardIndex + 1) / \(generator.trainingCards.count) 组")
                    .font(.subheadline)
                    .foregroundStyle(AzexTheme.textSecondary)
                Spacer()
                Button("返回") {
                    engine.stopAndRecognize()
                    phase = .termList
                }
                .buttonStyle(.plain)
                .foregroundStyle(AzexTheme.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            if let card {
                // Target terms
                HStack(spacing: 6) {
                    Text("目标术语：")
                        .font(.caption)
                        .foregroundStyle(AzexTheme.textTertiary)
                    ForEach(card.terms, id: \.self) { term in
                        Text(term)
                            .font(.caption.bold())
                            .foregroundStyle(AzexTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AzexTheme.accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                // Sentence to read
                Text(card.sentence)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AzexTheme.textPrimary)
                    .lineSpacing(8)
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .azexCard()
                    .padding(.horizontal, 20)
            }

            Spacer()

            // Recording controls
            if engine.isRecording {
                HStack(spacing: 10) {
                    Circle()
                        .fill(AzexTheme.recording)
                        .frame(width: 10, height: 10)
                    Text("请朗读上面的句子...")
                        .font(.callout.bold())
                        .foregroundStyle(AzexTheme.recording)
                }

                Button {
                    engine.stopAndRecognize()
                    waitForResult()
                } label: {
                    Label("完成朗读", systemImage: "stop.fill")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .tint(AzexTheme.recording)
                .controlSize(.large)
            } else {
                Text("按下按钮，朗读句子中的术语")
                    .font(.callout)
                    .foregroundStyle(AzexTheme.textSecondary)

                Button {
                    engine.startRecording()
                } label: {
                    Label("开始朗读", systemImage: "mic.fill")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .tint(AzexTheme.accent)
                .controlSize(.large)
            }

            Spacer()
        }
    }

    // MARK: - Result

    private var resultPhase: some View {
        VStack(spacing: 16) {
            Text("训练结果")
                .font(.title2.bold())
                .foregroundStyle(AzexTheme.textPrimary)
                .padding(.top, 20)

            // ASR output
            VStack(alignment: .leading, spacing: 8) {
                Text("识别结果")
                    .font(.caption)
                    .foregroundStyle(AzexTheme.textTertiary)
                Text(lastRecognized.isEmpty ? "(未检测到语音)" : lastRecognized)
                    .font(.callout)
                    .foregroundStyle(AzexTheme.textPrimary)
            }
            .azexCard()
            .padding(.horizontal, 20)

            // Matched terms
            if !matchedTerms.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("发音正确 (\(matchedTerms.count))", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(AzexTheme.success)

                    FlowLayoutSimple(spacing: 6) {
                        ForEach(matchedTerms, id: \.self) { term in
                            Text(term)
                                .font(.callout)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(AzexTheme.success.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .foregroundStyle(AzexTheme.textPrimary)
                        }
                    }
                }
                .azexCard()
                .padding(.horizontal, 20)
            }

            // Missed terms
            if !missedTerms.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("需要练习 (\(missedTerms.count))", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)

                    FlowLayoutSimple(spacing: 6) {
                        ForEach(missedTerms, id: \.self) { term in
                            Text(term)
                                .font(.callout)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .foregroundStyle(AzexTheme.textPrimary)
                        }
                    }
                }
                .azexCard()
                .padding(.horizontal, 20)
            }

            Spacer()

            // Navigation
            HStack(spacing: 16) {
                Button {
                    // Retry same card
                    lastRecognized = ""
                    matchedTerms = []
                    missedTerms = []
                    phase = .practicing
                } label: {
                    Label("重试", systemImage: "arrow.counterclockwise")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.bordered)
                .tint(AzexTheme.accent)
                .controlSize(.large)

                if currentCardIndex + 1 < generator.trainingCards.count {
                    Button {
                        currentCardIndex += 1
                        lastRecognized = ""
                        matchedTerms = []
                        missedTerms = []
                        phase = .practicing
                    } label: {
                        Label("下一组", systemImage: "chevron.right")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AzexTheme.accent)
                    .controlSize(.large)
                } else {
                    Button {
                        phase = .termList
                    } label: {
                        Text("完成训练")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AzexTheme.success)
                    .controlSize(.large)
                }
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Logic

    private func generateMaterials() {
        Task { @MainActor in
            generator.generate()
            phase = .termList
        }
    }

    private func waitForResult() {
        Task { @MainActor in
            while engine.recognizedText == nil {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            let recognized = engine.recognizedText ?? ""
            lastRecognized = recognized

            // Check which target terms were correctly recognized
            guard let card = generator.trainingCards.indices.contains(currentCardIndex)
                ? generator.trainingCards[currentCardIndex]
                : nil
            else {
                phase = .result
                return
            }

            let recognizedLower = recognized.lowercased()
            var matched: [String] = []
            var missed: [String] = []

            for term in card.terms {
                if recognizedLower.contains(term.lowercased()) {
                    matched.append(term)
                } else {
                    missed.append(term)
                }
            }

            matchedTerms = matched
            missedTerms = missed

            // If all terms matched, increment pass count and possibly mark mastered
            if missed.isEmpty {
                generator.trainingCards[currentCardIndex].passCount += 1
                if generator.trainingCards[currentCardIndex].isMastered {
                    for term in card.terms {
                        generator.markMastered(term)
                    }
                }
            }

            engine.recognizedText = nil
            phase = .result
        }
    }
}

// MARK: - Simple Flow Layout

private struct FlowLayoutSimple: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (i, pos) in result.positions.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxW = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, totalW: CGFloat = 0

        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > maxW && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            positions.append(CGPoint(x: x, y: y))
            rowH = max(rowH, s.height)
            x += s.width + spacing
            totalW = max(totalW, x)
        }
        return (CGSize(width: totalW, height: y + rowH), positions)
    }
}
