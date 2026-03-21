import Foundation

/// App-wide settings persisted via UserDefaults
enum AppSettings {
    nonisolated(unsafe) private static let defaults = UserDefaults.standard

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
