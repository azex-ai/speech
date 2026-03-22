@preconcurrency import AVFoundation
import Foundation

/// Standalone audio capture + ASR recognizer for calibration flow.
final class CalibrationEngine: ObservableObject, @unchecked Sendable {
    @Published var isRecording = false
    @Published var recognizedText: String?

    private var audioEngine: AVAudioEngine?
    private var recognizer: SpeechRecognizer?
    private var accumulatedSamples: [Float] = []

    var isReady: Bool { recognizer != nil }

    /// Prepare recognizer from ModelManager. Must call from MainActor context.
    @MainActor
    func prepare() {
        guard recognizer == nil else { return }
        if let modelPath = ModelManager.shared.modelPath,
           let tokensPath = ModelManager.shared.tokensPath
        {
            recognizer = SpeechRecognizer(modelPath: modelPath, tokensPath: tokensPath, hotwordsPath: nil)
        }
    }

    func startRecording() {
        guard !isRecording else { return }
        accumulatedSamples = []
        recognizedText = nil

        let engine = AVAudioEngine()
        self.audioEngine = engine

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

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

            if let channelData = converted.floatChannelData {
                let samples = Array(UnsafeBufferPointer(
                    start: channelData[0],
                    count: Int(converted.frameLength)
                ))
                self.accumulatedSamples.append(contentsOf: samples)
            }
        }

        engine.prepare()

        do {
            try engine.start()
            isRecording = true
        } catch {
            print("CalibrationEngine: failed to start audio engine: \(error)")
            isRecording = false
        }
    }

    func stopAndRecognize() {
        guard isRecording else { return }
        isRecording = false
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        let samples = accumulatedSamples
        accumulatedSamples = []

        guard !samples.isEmpty else {
            recognizedText = ""
            return
        }

        let rec = recognizer
        Task.detached {
            let text = rec?.recognize(samples: samples) ?? ""
            await MainActor.run {
                self.recognizedText = text
            }
        }
    }
}
