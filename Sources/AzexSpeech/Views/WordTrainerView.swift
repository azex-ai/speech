import SwiftUI

/// Train the ASR to recognize your pronunciation of specific words.
/// Flow: type correct word → record your pronunciation → app learns the mapping.
struct WordTrainerView: View {
    @StateObject private var engine = CalibrationEngine()
    @State private var targetWord = ""
    @State private var savedMappings: [(asrOutput: String, correctedWord: String, date: Date)] = []
    @State private var showSaved = false

    private let vocabManager = VocabManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Word Trainer")
                .font(.title2.bold())
                .foregroundStyle(AzexTheme.textPrimary)
                .padding(.horizontal, 24)
                .padding(.top, 20)

            Text("输入正确的单词，然后录制你的发音。App 会学习你的发音方式，自动纠正识别结果。")
                .font(.callout)
                .foregroundStyle(AzexTheme.textSecondary)
                .padding(.horizontal, 24)
                .padding(.top, 4)

            AzexTheme.border
                .frame(height: 1)
                .padding(.top, 16)

            // Input + Record
            VStack(spacing: 16) {
                // Target word input
                HStack(spacing: 12) {
                    Text("正确拼写")
                        .font(.callout)
                        .foregroundStyle(AzexTheme.textSecondary)
                        .frame(width: 70, alignment: .trailing)

                    TextField("例如: Claude Code", text: $targetWord)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                }

                // Record button
                HStack(spacing: 12) {
                    Text("录制发音")
                        .font(.callout)
                        .foregroundStyle(AzexTheme.textSecondary)
                        .frame(width: 70, alignment: .trailing)

                    Button {
                        if engine.isRecording {
                            engine.stopAndRecognize()
                        } else {
                            engine.startRecording()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: engine.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.title2)
                            Text(engine.isRecording ? "停止录音" : "开始录音")
                                .font(.callout)
                        }
                        .foregroundStyle(engine.isRecording ? AzexTheme.error : AzexTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(targetWord.trimmingCharacters(in: .whitespaces).isEmpty)

                    if engine.isRecording {
                        Circle()
                            .fill(AzexTheme.error)
                            .frame(width: 8, height: 8)
                            .opacity(0.8)
                    }
                }

                // Recognition result
                if let recognized = engine.recognizedText, !recognized.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        AzexTheme.border.frame(height: 1)

                        HStack(spacing: 12) {
                            Text("ASR 识别")
                                .font(.callout)
                                .foregroundStyle(AzexTheme.textSecondary)
                                .frame(width: 70, alignment: .trailing)

                            Text(recognized)
                                .font(.body.monospaced())
                                .foregroundStyle(AzexTheme.error)
                        }

                        HStack(spacing: 12) {
                            Text("纠正为")
                                .font(.callout)
                                .foregroundStyle(AzexTheme.textSecondary)
                                .frame(width: 70, alignment: .trailing)

                            Text(targetWord)
                                .font(.body.monospaced().bold())
                                .foregroundStyle(AzexTheme.success)
                        }

                        HStack(spacing: 12) {
                            Spacer().frame(width: 70)

                            Button("保存映射") {
                                saveMapping(asrOutput: recognized, correctedWord: targetWord)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AzexTheme.accent)

                            Button("重新录制") {
                                engine.recognizedText = nil
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            // Saved mappings
            if !savedMappings.isEmpty {
                AzexTheme.border
                    .frame(height: 1)
                    .padding(.top, 20)

                Text("本次已保存")
                    .font(.callout.bold())
                    .foregroundStyle(AzexTheme.textSecondary)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(savedMappings.indices, id: \.self) { i in
                            let m = savedMappings[i]
                            HStack(spacing: 8) {
                                Text(m.asrOutput)
                                    .font(.callout.monospaced())
                                    .foregroundStyle(AzexTheme.error.opacity(0.8))
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(AzexTheme.textSecondary)
                                Text(m.correctedWord)
                                    .font(.callout.monospaced().bold())
                                    .foregroundStyle(AzexTheme.success)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AzexTheme.success)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }

            Spacer()

            // Tip
            HStack(spacing: 6) {
                Image(systemName: "lightbulb")
                    .foregroundStyle(AzexTheme.accent)
                Text("提示：多录几次同一个词，覆盖不同语速和语调，识别效果更好。")
                    .font(.caption)
                    .foregroundStyle(AzexTheme.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AzexTheme.bg)
        .onAppear {
            engine.prepare()
            vocabManager.loadAll()
        }
    }

    private func saveMapping(asrOutput: String, correctedWord: String) {
        let trimmedASR = asrOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedWord = correctedWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedASR.isEmpty, !trimmedWord.isEmpty else { return }

        // Save to personal vocab (case-insensitive matching is handled by CorrectionEngine)
        vocabManager.learnCorrection(original: trimmedASR, corrected: trimmedWord)

        // Also save lowercase variant for robustness
        let lower = trimmedASR.lowercased()
        if lower != trimmedASR {
            vocabManager.learnCorrection(original: lower, corrected: trimmedWord)
        }

        savedMappings.append((asrOutput: trimmedASR, correctedWord: trimmedWord, date: Date()))

        // Reset for next recording
        engine.recognizedText = nil
        showSaved = true
    }
}
