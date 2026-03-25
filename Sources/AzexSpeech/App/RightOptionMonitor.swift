import AppKit
import Carbon.HIToolbox

/// Monitors the right Option key press/release globally.
/// Used as the default recording hotkey since KeyboardShortcuts doesn't support single modifier keys.
@MainActor
final class RightOptionMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastToggleTime: CFAbsoluteTime = 0
    private let onToggle: () -> Void

    init(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
    }

    func start() {
        // Global monitor for when app is not focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleFlagsChanged(event)
            }
        }

        // Local monitor for when app is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        // Only respond to RIGHT Option key (keyCode 61 = kVK_RightOption)
        guard event.keyCode == UInt16(kVK_RightOption) else { return }

        // Only respond to key-down (option flag present), ignore key-up
        guard event.modifierFlags.contains(.option) else { return }

        // Debounce 300ms — prevents double-fire from global+local monitors.
        // flagsChanged only fires once per press (not while held), so no
        // key-up tracking needed. This eliminates the "missed key-up" bug
        // that caused the second press to be ignored after idle/sleep.
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastToggleTime > 0.3 else { return }
        lastToggleTime = now
        onToggle()
    }
}
