import Foundation

/// Wraps sherpa-onnx offline FireRedASR v2 CTC recognizer (Chinese-English bilingual SOTA).
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
            numThreads: 4,
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

        var config = sherpaOnnxOfflineRecognizerConfig(
            featConfig: featConfig,
            modelConfig: modelConfig,
            decodingMethod: "greedy_search",
            hotwordsFile: resolvedHotwords,
            hotwordsScore: 2.0
        )

        // SherpaOnnxOfflineRecognizer fatalErrors on failure — check file validity first.
        // The failable init guards above should prevent bad paths reaching here.
        self.recognizer = SherpaOnnxOfflineRecognizer(config: &config)
        self.isReady = true
    }

    /// Recognize speech from audio samples.
    /// - Parameter samples: Float32 audio, normalized [-1, 1], 16kHz mono
    /// - Returns: Recognized text, or empty string on failure
    func recognize(samples: [Float]) -> String {
        guard !samples.isEmpty else { return "" }

        let result = recognizer.decode(samples: samples, sampleRate: 16_000)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
