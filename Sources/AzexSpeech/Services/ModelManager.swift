import Foundation

/// Manages the FireRedASR2 CTC model.
/// Model is bundled inside the app — no download needed.
/// Falls back to ~/Library/Application Support/ if bundle copy is missing (dev builds).
@MainActor
final class ModelManager: ObservableObject {
    static let shared = ModelManager()

    @Published private(set) var isModelReady = false

    /// Absolute path to model.int8.onnx, nil if not available.
    var modelPath: String? {
        guard isModelReady else { return nil }
        return resolvedModelPath
    }

    /// Absolute path to tokens.txt, nil if not available.
    var tokensPath: String? {
        guard isModelReady else { return nil }
        return resolvedTokensPath
    }

    private var resolvedModelPath: String?
    private var resolvedTokensPath: String?

    private init() {
        resolveModelPaths()
    }

    /// Check bundle first, then fall back to app support directory.
    private func resolveModelPaths() {
        // 1. Check app bundle (production: model bundled as resource)
        if let bundledModel = Bundle.module.url(forResource: "model.int8", withExtension: "onnx"),
           let bundledTokens = Bundle.module.url(forResource: "tokens", withExtension: "txt") {
            resolvedModelPath = bundledModel.path
            resolvedTokensPath = bundledTokens.path
            isModelReady = true
            print("✅ ASR model loaded from app bundle")
            return
        }

        // 2. Fall back to app support directory (dev builds / legacy)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelDir = appSupport.appendingPathComponent(
            "AzexSpeech/models/asr/sherpa-onnx-fire-red-asr2-ctc-zh_en-int8-2026-02-25",
            isDirectory: true
        )
        let modelFile = modelDir.appendingPathComponent("model.int8.onnx")
        let tokensFile = modelDir.appendingPathComponent("tokens.txt")

        let fm = FileManager.default
        if fm.fileExists(atPath: modelFile.path), fm.fileExists(atPath: tokensFile.path) {
            resolvedModelPath = modelFile.path
            resolvedTokensPath = tokensFile.path
            isModelReady = true
            print("✅ ASR model loaded from Application Support")
            return
        }

        print("⚠️ ASR model not found in bundle or Application Support")
        isModelReady = false
    }
}
