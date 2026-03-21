import Foundation

@MainActor
final class FeedManager: ObservableObject {
    static let shared = FeedManager()

    @Published var captures: [FeedCapture] = []

    private let feedDir: URL
    private let fileURL: URL

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("AzexSpeech", isDirectory: true)
            .appendingPathComponent("feed", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.feedDir = dir
        self.fileURL = dir.appendingPathComponent("captures.json")
        load()
    }

    /// Capture text from the current frontmost window
    func captureCurrentWindow() {
        guard let result = ContextCapture.captureActiveWindow() else { return }
        let hotwords = ContextCapture.extractHotwords(from: result.text)
        let capture = FeedCapture(
            timestamp: Date(),
            sourceApp: result.appName,
            text: result.text,
            hotwords: hotwords
        )
        captures.insert(capture, at: 0)
        save()
    }

    /// Delete a capture by id
    func deleteCapture(id: String) {
        captures.removeAll { $0.id == id }
        save()
    }

    /// Merged hotwords from all captures as identity mappings for VocabManager context words
    func allHotwords() -> [String: String] {
        var result: [String: String] = [:]
        for capture in captures {
            for word in capture.hotwords {
                result[word] = word
            }
        }
        return result
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let store = try? Self.decoder.decode(FeedStore.self, from: data)
        else {
            return
        }
        captures = store.captures
    }

    private func save() {
        let store = FeedStore(captures: captures)
        guard let data = try? Self.encoder.encode(store) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
