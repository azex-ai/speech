import Foundation

/// Manages progressive download and extraction of the Paraformer-zh ASR model.
/// Model is stored at ~/Library/Application Support/AzexSpeech/models/asr/.
@MainActor
final class ModelManager: ObservableObject {
    static let shared = ModelManager()

    private static let modelDirName = "sherpa-onnx-paraformer-zh-2024-03-09"
    private static let downloadURL = URL(
        string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-paraformer-zh-2024-03-09.tar.bz2"
    )!
    private static let requiredFiles = ["model.int8.onnx", "tokens.txt"]

    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false
    @Published private(set) var isModelReady = false
    @Published var error: String?

    /// Absolute path to model.int8.onnx, nil if not downloaded.
    var modelPath: String? {
        guard isModelReady else { return nil }
        return modelDirectory.appendingPathComponent("model.int8.onnx").path
    }

    /// Absolute path to tokens.txt, nil if not downloaded.
    var tokensPath: String? {
        guard isModelReady else { return nil }
        return modelDirectory.appendingPathComponent("tokens.txt").path
    }

    private var activeDownload: URLSessionDownloadTask?

    private var baseDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("AzexSpeech/models/asr", isDirectory: true)
    }

    private var modelDirectory: URL {
        baseDirectory.appendingPathComponent(Self.modelDirName, isDirectory: true)
    }

    private init() {
        isModelReady = checkModelFiles()
    }

    private func checkModelFiles() -> Bool {
        let fm = FileManager.default
        return Self.requiredFiles.allSatisfy { file in
            fm.fileExists(atPath: modelDirectory.appendingPathComponent(file).path)
        }
    }

    /// Downloads and extracts the model if it is not already present.
    func downloadModelIfNeeded() async {
        guard !isModelReady, !isDownloading else { return }

        isDownloading = true
        error = nil
        downloadProgress = 0

        do {
            let fm = FileManager.default
            try fm.createDirectory(at: baseDirectory, withIntermediateDirectories: true)

            // Use URLSessionDownloadTask with delegate for native download speed + progress
            let tempURL = try await downloadWithProgress(Self.downloadURL)

            downloadProgress = 0.95
            try await extractArchive(at: tempURL)
            try? fm.removeItem(at: tempURL)

            downloadProgress = 1.0
            isModelReady = checkModelFiles()
            if !isModelReady {
                error = "Extraction completed but model files are missing."
            }
        } catch is CancellationError {
            error = "Download cancelled."
        } catch {
            self.error = error.localizedDescription
        }

        isDownloading = false
    }

    func cancelDownload() {
        activeDownload?.cancel()
        activeDownload = nil
    }

    // MARK: - Download with native URLSessionDownloadTask

    private func downloadWithProgress(_ url: URL) async throws -> URL {
        let delegate = DownloadDelegate { [weak self] progress in
            Task { @MainActor in
                self?.downloadProgress = progress * 0.95 // Reserve 5% for extraction
            }
        }

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: url) { tempURL, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let tempURL else {
                    continuation.resume(throwing: NSError(
                        domain: "ModelManager", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Download produced no file"]
                    ))
                    return
                }

                // Move temp file to a stable location before the callback returns
                let stableURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("paraformer-zh.tar.bz2")
                try? FileManager.default.removeItem(at: stableURL)
                do {
                    try FileManager.default.moveItem(at: tempURL, to: stableURL)
                    continuation.resume(returning: stableURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            activeDownload = task
            task.resume()
        }
    }

    // MARK: - Extraction

    private func extractArchive(at archiveURL: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["xjf", archiveURL.path, "-C", baseDirectory.path]

            let errorPipe = Pipe()
            process.standardError = errorPipe

            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let msg = String(data: errorData, encoding: .utf8) ?? "Unknown extraction error"
                    continuation.resume(throwing: NSError(
                        domain: "ModelManager",
                        code: Int(proc.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: "Extraction failed: \(msg)"]
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - URLSession Download Delegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let onProgress: @Sendable (Double) -> Void

    init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : 217_000_000
        let progress = Double(totalBytesWritten) / Double(total)
        onProgress(min(progress, 1.0))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Handled in completion handler
    }
}
