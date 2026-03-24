import AppKit
import Carbon.HIToolbox

/// Monitors the right Option key press/release globally.
/// Used as the default recording hotkey since KeyboardShortcuts doesn't support single modifier keys.
@MainActor
final class RightOptionMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isRightOptionDown = false
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
            // Already on main thread — handle synchronously to prevent race with global monitor
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
        // Check if it's the RIGHT Option key specifically
        // Right Option has keyCode 61 (kVK_RightOption)
        let isRightOption = event.keyCode == UInt16(kVK_RightOption)

        guard isRightOption else { return }

        let optionPressed = event.modifierFlags.contains(.option)

        if optionPressed && !isRightOptionDown {
            // Key down — toggle recording (debounce 200ms to prevent double-fire from both monitors)
            let now = CFAbsoluteTimeGetCurrent()
            guard now - lastToggleTime > 0.2 else { return }
            isRightOptionDown = true
            lastToggleTime = now
            onToggle()
        } else if !optionPressed && isRightOptionDown {
            // Key up — just reset state (toggle mode, not hold mode)
            isRightOptionDown = false
        }
    }

    // Cleanup handled by stop() — called before deallocation
}
