import AppKit

/// Plays system sounds for recording start/stop feedback.
/// Uses macOS built-in system sounds — no custom audio files needed.
enum SoundEffect {
    /// Play the recording-start sound (short, subtle)
    static func playStart() {
        guard AppSettings.soundEnabled else { return }
        NSSound(named: "Tink")?.play()
    }

    /// Play the recording-stop sound (soft, gentle)
    static func playStop() {
        guard AppSettings.soundEnabled else { return }
        NSSound(named: "Pop")?.play()
    }
}
