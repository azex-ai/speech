@preconcurrency import AVFoundation
import Foundation

/// Core speech recognition engine.
/// Captures audio → recognizes via FireRedASR v2 CTC → corrects with vocab → returns text.
final class SpeechEngine: @unchecked Sendable {
    private var audioEngine: AVAudioEngine?
    private var audioBuffer: RingBuffer<Float>
    private(set) var isRecording = false

    let vocabManager: VocabManager
    let correctionEngine: CorrectionEngine
    private var recognizer: SpeechRecognizer?

    /// Accumulated audio samples during recording (16kHz mono Float32, [-1, 1])
    private var accumulatedSamples: [Float] = []

    private var onTextUpdate: (@Sendable (String) -> Void)?

    init() {
        self.audioBuffer = RingBuffer(capacity: 16000) // 1 second at 16kHz
        self.vocabManager = VocabManager()
        self.correctionEngine = CorrectionEngine(vocabManager: vocabManager)
    }

    func initialize() async {
        vocabManager.loadAll()

        // Initialize ASR recognizer if model is available
        let modelPath = await ModelManager.shared.modelPath
        let tokensPath = await ModelManager.shared.tokensPath
        let hotwordsPath = Bundle.main.url(forResource: "hotwords", withExtension: "txt")?.path
        if let modelPath, let tokensPath {
            recognizer = SpeechRecognizer(modelPath: modelPath, tokensPath: tokensPath, hotwordsPath: hotwordsPath)
            if recognizer != nil {
                print("✅ FireRedASR v2 CTC recognizer ready")
            } else {
                print("⚠️ Failed to initialize FireRedASR v2 CTC recognizer")
            }
        } else {
            print("⚠️ ASR model not downloaded yet")
        }

        setupAudioEngine()
    }

    func startRecording(onUpdate: @escaping @Sendable (String) -> Void) {
        guard !isRecording else { return }
        self.onTextUpdate = onUpdate
        self.accumulatedSamples = []
        isRecording = true

        do {
            try audioEngine?.start()
        } catch {
            print("Failed to start audio engine: \(error)")
            isRecording = false
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        audioEngine?.stop()

        let samples = accumulatedSamples
        accumulatedSamples = []

        guard !samples.isEmpty else {
            onTextUpdate?("")
            return
        }

        // Run recognition on background thread to avoid blocking UI
        let rec = recognizer
        let correction = correctionEngine
        nonisolated(unsafe) let callback = onTextUpdate

        Task.detached {
            let text: String
            if let recognized = rec?.recognize(samples: samples), !recognized.isEmpty {
                // Post-process with correction engine (vocab replacement)
                text = correction.correct(recognized)
            } else {
                text = "[ASR not available — download model in Settings]"
            }

            await MainActor.run {
                callback?(text)
            }
        }
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Target: 16kHz mono Float32 for FireRedASR
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else { return }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else { return }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) {
            [weak self] buffer, _ in
            guard let self, self.isRecording else { return }

            // Resample to 16kHz
            let frameCapacity = AVAudioFrameCount(
                Double(buffer.frameLength) * 16000.0 / buffer.format.sampleRate
            )
            guard let converted = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: frameCapacity
            ) else { return }

            let inputBuffer = buffer
            nonisolated(unsafe) var consumed = false
            converter.convert(to: converted, error: nil) { _, status in
                if !consumed {
                    consumed = true
                    status.pointee = .haveData
                    return inputBuffer
                }
                status.pointee = .noDataNow
                return nil
            }

            // Accumulate resampled audio during recording
            if let channelData = converted.floatChannelData {
                let samples = Array(UnsafeBufferPointer(
                    start: channelData[0],
                    count: Int(converted.frameLength)
                ))
                self.audioBuffer.write(samples)
                self.accumulatedSamples.append(contentsOf: samples)
            }
        }

        // Prepare engine (don't start yet)
        engine.prepare()
    }
}
