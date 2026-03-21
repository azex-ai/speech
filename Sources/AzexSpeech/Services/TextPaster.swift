import AppKit
import Carbon.HIToolbox

enum TextPaster {
    /// Copy text to clipboard and simulate Cmd+V paste.
    @MainActor
    static func paste(_ text: String, delay: TimeInterval = 0.05) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            simulateCmdV()
        }
    }

    private static func simulateCmdV() {
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: true
        ) else { return }
        keyDown.flags = .maskCommand

        guard let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: false
        ) else { return }
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

// MARK: - Accessibility Permission

extension TextPaster {
    /// Check if Accessibility permission is granted, prompt if not.
    static func ensureAccessibilityPermission() {
        // Use string literal to avoid Swift 6 concurrency error with kAXTrustedCheckOptionPrompt global
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            print("Accessibility permission needed for paste functionality")
        }
    }
}
