@preconcurrency import AVFoundation
import Foundation

/// Core speech recognition engine.
/// Captures audio → recognizes via FireRedASR2 AED → corrects with vocab → returns text.
final class SpeechEngine: @unchecked Sendable {
    private var audioEngine: AVAudioEngine?
    private var audioBuffer: RingBuffer<Float>
    private(set) var isRecording = false

    let vocabManager: VocabManager
    let correctionEngine: CorrectionEngine
    private var recognizer: SpeechRecognizer?

    /// Accumulated audio samples during recording (16kHz mono Float32, [-1, 1])
    /// Protected by samplesLock for thread-safe access between audio tap and main thread.
    private var accumulatedSamples: [Float] = []
    private let samplesLock = NSLock()

    private var onTextUpdate: (@Sendable (String) -> Void)?

    init() {
        self.audioBuffer = RingBuffer(capacity: 16000) // 1 second at 16kHz
        self.vocabManager = VocabManager()
        self.correctionEngine = CorrectionEngine(vocabManager: vocabManager)
    }

    /// Debounce timer for vocab reload notifications
    private var vocabReloadWorkItem: DispatchWorkItem?

    func initialize() async {
        vocabManager.loadAll()

        // Reload vocab when WordTrainer saves new mappings (debounced 500ms)
        NotificationCenter.default.addObserver(forName: .vocabDidUpdate, object: nil, queue: .main) { [weak self] _ in
            self?.vocabReloadWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.vocabManager.loadAll()
            }
            self?.vocabReloadWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        }

        // Initialize ASR recognizer if model is available
        let modelPath = await ModelManager.shared.modelPath
        let tokensPath = await ModelManager.shared.tokensPath
        let hotwordsPath = Bundle.module.url(forResource: "hotwords", withExtension: "txt")?.path
        if let modelPath, let tokensPath {
            recognizer = SpeechRecognizer(modelPath: modelPath, tokensPath: tokensPath, hotwordsPath: hotwordsPath)
            if recognizer != nil {
                print("✅ FireRedASR2 CTC recognizer ready")
            } else {
                print("⚠️ Failed to initialize FireRedASR2 CTC recognizer")
            }
        } else {
            print("⚠️ ASR model not downloaded yet")
        }

        setupAudioEngine()
    }

    func startRecording(onUpdate: @escaping @Sendable (String) -> Void) {
        guard !isRecording else { return }
        self.onTextUpdate = onUpdate
        samplesLock.lock()
        self.accumulatedSamples = []
        self.accumulatedSamples.reserveCapacity(16000 * 30) // pre-alloc ~30s at 16kHz
        samplesLock.unlock()
        isRecording = true

        // Engine stays running (started in setupAudioEngine).
        // Audio tap always runs; isRecording controls whether samples accumulate.
        // This eliminates startup latency so the first syllable is captured.
        if audioEngine?.isRunning != true {
            do {
                try audioEngine?.start()
            } catch {
                print("Failed to start audio engine: \(error)")
                isRecording = false
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false

        // Don't stop the engine — keep it warm for next recording.
        // Safely extract accumulated samples under lock, then add silence padding.
        samplesLock.lock()
        accumulatedSamples.append(contentsOf: [Float](repeating: 0, count: 1600)) // 0.1s padding
        let samples = accumulatedSamples
        accumulatedSamples = []
        samplesLock.unlock()

        guard !samples.isEmpty else {
            onTextUpdate?("")
            return
        }

        // Run recognition on background thread to avoid blocking UI
        let rec = recognizer
        let correction = correctionEngine
        let callback = onTextUpdate
        let useCloud = AppSettings.asrEngine == .cloud && !AppSettings.volcApiKey.isEmpty

        Task.detached {
            let recognized: String
            if useCloud {
                let cloudRecognizer = VolcEngineRecognizer(apiKey: AppSettings.volcApiKey)
                recognized = await cloudRecognizer.recognize(samples: samples)
            } else if let localResult = rec?.recognize(samples: samples), !localResult.isEmpty {
                recognized = localResult
            } else {
                recognized = "[ASR not available — download model in Settings]"
            }

            // Post-process with correction engine (vocab replacement) unless it's an error
            let text: String
            if recognized.hasPrefix("[") {
                text = recognized
            } else {
                let corrected = correction.correct(recognized)
                let logMsg = "📝 Correction: \"\(recognized)\" → \"\(corrected)\"\n"
                let logPath = "/tmp/azex-asr.log"
                if let fh = FileHandle(forWritingAtPath: logPath) {
                    fh.seekToEndOfFile()
                    fh.write(Data(logMsg.utf8))
                    fh.closeFile()
                }
                text = corrected
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

            // Accumulate resampled audio during recording (thread-safe)
            if let channelData = converted.floatChannelData {
                let samples = Array(UnsafeBufferPointer(
                    start: channelData[0],
                    count: Int(converted.frameLength)
                ))
                self.audioBuffer.write(samples)
                self.samplesLock.lock()
                self.accumulatedSamples.append(contentsOf: samples)
                self.samplesLock.unlock()
            }
        }

        // Start engine immediately and keep it running.
        // The tap always fires; isRecording controls whether samples accumulate.
        // This eliminates cold-start latency when the user presses the hotkey.
        engine.prepare()
        do {
            try engine.start()
        } catch {
            print("Failed to pre-start audio engine: \(error)")
        }
    }
}
