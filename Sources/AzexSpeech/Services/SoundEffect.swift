import AppKit

/// Plays system sounds for recording start/stop feedback.
/// Uses macOS built-in system sounds — no custom audio files needed.
enum SoundEffect {
    /// Debounce: prevent the same sound from playing twice within 300ms
    /// (global + local event monitors can both fire for the same keypress)
    nonisolated(unsafe) private static var lastPlayTime: CFAbsoluteTime = 0

    /// Play the recording-start sound (short, subtle)
    static func playStart() {
        guard AppSettings.soundEnabled else { return }
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastPlayTime > 0.3 else { return }
        lastPlayTime = now
        NSSound(named: "Tink")?.play()
    }

    /// Play the recording-stop sound (soft, gentle)
    static func playStop() {
        guard AppSettings.soundEnabled else { return }
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastPlayTime > 0.3 else { return }
        lastPlayTime = now
        NSSound(named: "Pop")?.play()
    }
}
