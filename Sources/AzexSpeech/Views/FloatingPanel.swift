import AppKit
import SwiftUI

/// Observable state shared between FloatingPanel (NSPanel) and FloatingPanelContent (SwiftUI)
@MainActor
final class FloatingPanelState: ObservableObject {
    @Published var text: String = ""
    @Published var isRecognizing: Bool = true
    var originalASRText: String = ""
}

/// Floating panel that appears near cursor for voice input display + editing
@MainActor
final class FloatingPanel: NSPanel {
    let state = FloatingPanelState()
    var onConfirm: ((String, String) -> Void)?

    init(onConfirm: ((String, String) -> Void)? = nil) {
        self.onConfirm = onConfirm
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 80),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = false

        setupContent()
    }

    func showNearCursor() {
        let mouseLocation = NSEvent.mouseLocation
        let origin = NSPoint(
            x: mouseLocation.x - 200,
            y: mouseLocation.y - 100
        )
        setFrameOrigin(origin)
        orderFrontRegardless()
    }

    func updateText(_ text: String) {
        if state.originalASRText.isEmpty {
            state.originalASRText = text
        }
        state.text = text
    }

    func finishRecognizing() {
        state.isRecognizing = false
    }

    func dismiss() {
        orderOut(nil)
    }

    private func setupContent() {
        let hostView = NSHostingView(rootView: FloatingPanelContent(
            state: state,
            onConfirm: { [weak self] editedText in
                guard let self else { return }
                self.onConfirm?(self.state.originalASRText, editedText)
                self.dismiss()
            },
            onCancel: { [weak self] in
                self?.dismiss()
            }
        ))

        contentView = hostView
    }
}

struct FloatingPanelContent: View {
    @ObservedObject var state: FloatingPanelState

    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if state.isRecognizing && state.text.isEmpty {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Listening...")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(minHeight: 40)
            } else {
                TextEditor(text: $state.text)
                    .font(.system(size: 14, design: .default))
                    .frame(minHeight: 40, maxHeight: 120)
                    .scrollContentBackground(.hidden)
            }

            HStack {
                if state.isRecognizing {
                    Text("Recognizing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Enter 确认粘贴 · Esc 取消")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
        .frame(width: 400)
        .onKeyPress(.return) {
            guard !state.isRecognizing else { return .ignored }
            onConfirm(state.text)
            return .handled
        }
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
    }
}
