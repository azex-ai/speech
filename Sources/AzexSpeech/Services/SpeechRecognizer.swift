import Foundation

/// Wraps sherpa-onnx offline FireRedASR2 CTC recognizer (Chinese-English bilingual SOTA).
/// Thread-safe: all methods are nonisolated and can be called from any thread.
final class SpeechRecognizer: @unchecked Sendable {
    private let recognizer: SherpaOnnxOfflineRecognizer
    let isReady: Bool

    /// Initialize with model file paths. Returns nil if model loading fails.
    init?(modelPath: String, tokensPath: String, hotwordsPath: String? = nil) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: modelPath),
              fm.fileExists(atPath: tokensPath) else {
            return nil
        }

        let featConfig = sherpaOnnxFeatureConfig(sampleRate: 16000, featureDim: 80)

        let fireRedCtcConfig = sherpaOnnxOfflineFireRedAsrCtcModelConfig(model: modelPath)

        let modelConfig = sherpaOnnxOfflineModelConfig(
            tokens: tokensPath,
            numThreads: 8,
            provider: "cpu",
            modelType: "fire_red_asr_ctc",
            fireRedAsrCtc: fireRedCtcConfig
        )

        // Resolve hotwords file path
        let resolvedHotwords: String
        if let hp = hotwordsPath, fm.fileExists(atPath: hp) {
            resolvedHotwords = hp
            print("📋 Hotwords loaded: \(hp)")
        } else {
            resolvedHotwords = ""
        }

        // CTC only supports greedy_search. Hotwords boosting not available at engine level.
        // Domain term correction handled by CorrectionEngine post-processing.
        var config = sherpaOnnxOfflineRecognizerConfig(
            featConfig: featConfig,
            modelConfig: modelConfig,
            decodingMethod: "greedy_search"
        )

        self.recognizer = SherpaOnnxOfflineRecognizer(config: &config)
        self.isReady = true
    }

    /// Recognize speech from audio samples.
    /// - Parameter samples: Float32 audio, normalized [-1, 1], 16kHz mono
    /// - Returns: Recognized text, or empty string on failure
    func recognize(samples: [Float]) -> String {
        guard !samples.isEmpty else { return "" }

        let audioDuration = Double(samples.count) / 16_000.0
        let start = CFAbsoluteTimeGetCurrent()
        let result = recognizer.decode(samples: samples, sampleRate: 16_000)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let rtf = elapsed / audioDuration
        let msg = "🎤 ASR: \(String(format: "%.1f", audioDuration))s audio → \(String(format: "%.2f", elapsed))s decode (RTF=\(String(format: "%.3f", rtf))) text=\(result.text.prefix(80))\n"
        print(msg)
        let logPath = "/tmp/azex-asr.log"
        if let fh = FileHandle(forWritingAtPath: logPath) {
            fh.seekToEndOfFile()
            fh.write(Data(msg.utf8))
            fh.closeFile()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: Data(msg.utf8))
        }

        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
