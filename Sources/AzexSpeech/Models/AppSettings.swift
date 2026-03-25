import Foundation

/// App-wide settings persisted via UserDefaults
enum AppSettings {
    nonisolated(unsafe) private static let defaults = UserDefaults.standard

    /// ASR engine selection
    enum ASREngine: String {
        case local  // FireRedASR2 CTC (offline)
        case cloud  // Volcengine Seed-ASR 2.0
    }

    /// Which ASR engine to use. Default: local.
    static var asrEngine: ASREngine {
        get { ASREngine(rawValue: defaults.string(forKey: "asrEngine") ?? "") ?? .local }
        set { defaults.set(newValue.rawValue, forKey: "asrEngine") }
    }

    /// Volcengine API Key (from 豆包语音新版控制台).
    static var volcApiKey: String {
        get { defaults.string(forKey: "volcApiKey") ?? "" }
        set { defaults.set(newValue, forKey: "volcApiKey") }
    }

    /// If true, recognized text is auto-pasted without edit confirmation.
    /// If false, floating panel appears for user to review/edit before pasting.
    static var autoPasteMode: Bool {
        get { defaults.object(forKey: "autoPasteMode") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "autoPasteMode") }
    }

    /// Sound effects for recording start/stop. Default: on.
    static var soundEnabled: Bool {
        get { defaults.object(forKey: "soundEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "soundEnabled") }
    }
}
