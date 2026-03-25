import AppKit
import KeyboardShortcuts
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var speechEngine: SpeechEngine?
    private var floatingPanel: FloatingPanel?
    private var recordingIndicator: RecordingIndicator?
    private var rightOptionMonitor: RightOptionMonitor?
    private var modelDownloadWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var mainPopover: MainPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — menu bar only
        NSApp.setActivationPolicy(.accessory)

        TextPaster.ensureAccessibilityPermission()
        setupStatusBar()
        setupHotkey()

        // Check onboarding first, then model, then engine
        if !isOnboardingComplete() {
            showOnboarding()
        } else if ModelManager.shared.isModelReady {
            initializeEngine()
        } else {
            showModelDownloadWindow()
        }
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Azex Speech")
            button.action = #selector(statusBarClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusBarClicked() {
        guard let event = NSApp.currentEvent, let button = statusItem?.button else { return }

        if event.type == .rightMouseUp {
            // Right-click: show context menu
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil  // Reset so left-click works next time
        } else {
            // Left-click: toggle popover
            if mainPopover == nil {
                mainPopover = MainPopover()
            }
            mainPopover?.toggle(relativeTo: button)
        }
    }

    private func setupHotkey() {
        // Right Option key as default (single modifier key, not supported by KeyboardShortcuts)
        rightOptionMonitor = RightOptionMonitor { [weak self] in
            self?.toggleRecording()
        }
        rightOptionMonitor?.start()

        // Also keep KeyboardShortcuts for custom override
        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            self?.toggleRecording()
        }
    }

    private func initializeEngine() {
        let engine = SpeechEngine()
        self.speechEngine = engine

        Task { @MainActor in
            await engine.initialize()
        }
    }

    // MARK: - Onboarding

    private func isOnboardingComplete() -> Bool {
        let path = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AzexSpeech/onboarding-complete.json")
        return FileManager.default.fileExists(atPath: path.path)
    }

    private func showOnboarding() {
        let view = OnboardingContentView(onComplete: { [weak self] in
            self?.completeOnboarding()
        })
        let hostingView = NSHostingView(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.center()
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1)

        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func completeOnboarding() {
        // Write onboarding state
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AzexSpeech")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let state = OnboardingState(
            completed: true,
            domain: "both",
            completedAt: ISO8601DateFormatter().string(from: Date())
        )
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: dir.appendingPathComponent("onboarding-complete.json"))
        }

        onboardingWindow?.close()
        onboardingWindow = nil

        // Continue to model check / engine init
        if ModelManager.shared.isModelReady {
            initializeEngine()
        } else {
            showModelDownloadWindow()
        }
    }

    // MARK: - Model Missing Window

    private func showModelDownloadWindow() {
        let view = ModelMissingView()
        let hostingView = NSHostingView(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 368, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = "Azex Speech"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating

        modelDownloadWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Recording

    /// Prevents re-triggering during recognition/paste
    private var isProcessing = false
    /// Timestamp when isProcessing was set to true, for safety timeout
    private var processingStartTime: CFAbsoluteTime = 0
    /// Tracks when recording started for duration calculation
    private var recordingStartTime: Date?
    /// Stores the raw ASR text before correction (for history diff)
    private var lastRawASRText: String?

    private func toggleRecording() {
        guard let engine = speechEngine else { return }

        // Block input during recognizing/done/error states, but auto-unlock after 15s safety timeout
        if isProcessing {
            let elapsed = CFAbsoluteTimeGetCurrent() - processingStartTime
            if elapsed < 15.0 { return }
            // Safety timeout: recognition likely hung, force unlock
            print("⚠️ isProcessing stuck for \(Int(elapsed))s — force unlocking")
            isProcessing = false
        }

        if engine.isRecording {
            // Second press: stop recording → recognize
            SoundEffect.playStop()
            isProcessing = true
            processingStartTime = CFAbsoluteTimeGetCurrent()
            updateStatusIcon(recording: false)

            if AppSettings.autoPasteMode {
                if recordingIndicator == nil { recordingIndicator = RecordingIndicator() }
                recordingIndicator?.show(state: .recognizing)
                engine.stopRecording()
            } else {
                engine.stopRecording()
                floatingPanel?.finishRecognizing()
                isProcessing = false
            }
        } else {
            // First press: start recording
            SoundEffect.playStart()
            recordingStartTime = Date()
            updateStatusIcon(recording: true)

            if AppSettings.autoPasteMode {
                if recordingIndicator == nil { recordingIndicator = RecordingIndicator() }
                recordingIndicator?.show(state: .recording)

                engine.startRecording { [weak self] text in
                    Task { @MainActor in
                        self?.handleAutoPaste(text: text)
                    }
                }
            } else {
                let panel = FloatingPanel(onConfirm: { [weak self] original, edited in
                    self?.handlePanelConfirm(original: original, edited: edited)
                })
                floatingPanel = panel
                panel.showNearCursor()
                engine.startRecording { [weak self] text in
                    Task { @MainActor in
                        self?.floatingPanel?.updateText(text)
                        self?.floatingPanel?.finishRecognizing()
                    }
                }
            }
        }
    }

    private func handleAutoPaste(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let durationMs = Int((Date().timeIntervalSince(recordingStartTime ?? Date())) * 1000)

        guard !trimmed.isEmpty, !trimmed.starts(with: "[") else {
            recordingIndicator?.show(state: .error("识别失败"))
            // Unlock immediately — user can start new recording right away
            isProcessing = false
            return
        }

        // Show done
        recordingIndicator?.show(state: .done(""))
        TextPaster.paste(trimmed)

        // Record to history + stats
        recordSession(original: trimmed, corrected: trimmed, durationMs: durationMs, learned: [])

        // Unlock immediately — indicator auto-dismisses on its own timer
        isProcessing = false
    }

    private func handlePanelConfirm(original: String, edited: String) {
        let durationMs = Int((Date().timeIntervalSince(recordingStartTime ?? Date())) * 1000)
        var learnedPairs: [[String]] = []

        if let engine = speechEngine, original != edited {
            let pairs = engine.correctionEngine.extractCorrections(
                original: original, edited: edited
            )
            for (orig, corrected) in pairs {
                engine.vocabManager.learnCorrection(original: orig, corrected: corrected)
                learnedPairs.append([orig, corrected])
            }
        }

        floatingPanel?.dismiss()
        floatingPanel = nil

        let text = edited.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        TextPaster.paste(text)

        // Record to history + stats
        recordSession(original: original, corrected: text, durationMs: durationMs, learned: learnedPairs)
    }

    /// Record a completed session to HistoryManager + StatsManager
    private func recordSession(original: String, corrected: String, durationMs: Int, learned: [[String]]) {
        let entry = HistoryEntry(
            timestamp: Date(),
            original: original,
            corrected: corrected,
            learned: learned,
            durationMs: durationMs,
            charCount: corrected.count
        )
        HistoryManager.shared.addEntry(entry)
        StatsManager.shared.recordSession(charCount: corrected.count, durationMs: durationMs)
    }

    private func updateStatusIcon(recording: Bool) {
        statusItem?.button?.image = NSImage(
            systemSymbolName: recording ? "waveform.circle.fill" : "waveform",
            accessibilityDescription: "Azex Speech"
        )
    }

    @objc private func openSettings() {
        if mainPopover == nil {
            mainPopover = MainPopover()
        }
        if let button = statusItem?.button {
            mainPopover?.toggle(relativeTo: button)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
