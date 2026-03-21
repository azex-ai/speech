import AppKit
import SwiftUI

/// Manages the main app popover that appears when clicking the menu bar icon.
@MainActor
final class MainPopover {
    private var popover: NSPopover?
    private var eventMonitor: Any?

    func toggle(relativeTo button: NSStatusBarButton) {
        if let popover, popover.isShown {
            popover.performClose(nil)
            return
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 720, height: 560)
        popover.behavior = .transient
        popover.animates = true

        let hostingView = NSHostingView(rootView: MainContentView())
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = hostingView

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        self.popover = popover
    }

    func close() {
        popover?.performClose(nil)
        popover = nil
    }
}
