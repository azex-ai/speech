import AppKit
import SwiftUI

// MARK: - State

enum RecordingState: Equatable {
    case idle
    case recording
    case recognizing
    case done(String)   // pasted text preview
    case error(String)
}

// MARK: - Indicator Window

/// A floating indicator bar at the bottom center of the screen.
/// Shows recording/recognizing/done states without interrupting user flow.
@MainActor
final class RecordingIndicator {
    private var window: NSWindow?
    private var stateModel = RecordingIndicatorState()

    private var dismissTask: Task<Void, Never>?

    func show(state: RecordingState) {
        // Cancel any pending dismiss
        dismissTask?.cancel()
        dismissTask = nil

        if window == nil {
            createWindow()
        }

        // Ensure window is fully visible (cancel any fade-out in progress)
        window?.alphaValue = 1

        stateModel.state = state
        repositionToActiveScreen()
        window?.orderFrontRegardless()

        // Auto-dismiss for terminal states
        if case .done = state {
            scheduleDismiss(after: 2.0)
        } else if case .error = state {
            scheduleDismiss(after: 3.0)
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            window?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
            self?.window?.alphaValue = 1
            self?.stateModel.state = .idle
        }
    }

    private func scheduleDismiss(after seconds: TimeInterval) {
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    /// Reposition indicator to bottom center of the screen where the mouse cursor is.
    private func repositionToActiveScreen() {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
        guard let screen, let window else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - window.frame.width / 2
        let y = screenFrame.minY + 60
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func createWindow() {
        let view = RecordingIndicatorView(model: stateModel)
        let hostingView = NSHostingView(rootView: view)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 36),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false  // No window-level shadow — SwiftUI capsule handles its own
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.contentView = hostingView
        hostingView.layer?.backgroundColor = .clear

        repositionToActiveScreen()

        window = panel
    }
}

// MARK: - Observable State

@MainActor
final class RecordingIndicatorState: ObservableObject {
    @Published var state: RecordingState = .idle
}

// MARK: - SwiftUI View

struct RecordingIndicatorView: View {
    @ObservedObject var model: RecordingIndicatorState

    var body: some View {
        Group {
            switch model.state {
            case .idle:
                EmptyView()
            case .recording:
                indicatorCapsule {
                    WaveformBars()
                    Text("录音中")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AzexTheme.textPrimary)
                }
            case .recognizing:
                indicatorCapsule {
                    BouncingDots()
                    Text("识别中")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AzexTheme.textPrimary)
                }
            case .done:
                indicatorCapsule {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AzexTheme.success)
                    Text("已粘贴")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AzexTheme.textPrimary)
                }
            case .error(let msg):
                indicatorCapsule {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AzexTheme.error)
                    Text(msg)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AzexTheme.textPrimary)
                        .lineLimit(1)
                }
            }
        }
        .frame(width: 160, height: 36)
        .animation(.easeInOut(duration: 0.3), value: model.state)
    }

    @ViewBuilder
    private func indicatorCapsule<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 6) {
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AzexTheme.bgCard)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(AzexTheme.border, lineWidth: 1)
        )
    }
}

// MARK: - Waveform Animation (Recording)

private struct WaveformBars: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(AzexTheme.recording)
                    .frame(width: 3, height: animating ? heights[i].max : heights[i].min)
                    .animation(
                        .easeInOut(duration: durations[i])
                        .repeatForever(autoreverses: true)
                        .delay(delays[i]),
                        value: animating
                    )
            }
        }
        .frame(width: 18, height: 16)
        .onAppear { animating = true }
    }

    private let heights: [(min: CGFloat, max: CGFloat)] = [
        (4, 14), (6, 10), (3, 16), (5, 12)
    ]
    private let durations: [Double] = [0.4, 0.35, 0.45, 0.38]
    private let delays: [Double] = [0, 0.1, 0.05, 0.15]
}

// MARK: - Bouncing Dots (Recognizing)

private struct BouncingDots: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(AzexTheme.accent)
                    .frame(width: 5, height: 5)
                    .offset(y: animating ? -4 : 0)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.15),
                        value: animating
                    )
            }
        }
        .frame(width: 22, height: 16)
        .onAppear { animating = true }
    }
}
