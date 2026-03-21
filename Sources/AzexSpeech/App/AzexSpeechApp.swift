import SwiftUI

@main
struct AzexSpeechApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu Bar only — no main window
        Settings {
            SettingsView()
        }
    }
}
