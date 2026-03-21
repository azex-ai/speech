# Phase 1: Core Usable — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Azex Speech actually recognize speech — integrate sherpa-onnx Paraformer-zh, wire the full pipeline from recording → ASR → correction → floating panel → paste, and add progressive model download.

**Architecture:** sherpa-onnx XCFramework (pre-built static library) provides C API for offline Paraformer-zh recognition. A Swift wrapper (`SherpaOnnx.swift` from upstream) bridges C→Swift. Audio accumulates during recording, then feeds to offline recognizer on stop. Correction engine post-processes ASR output. Confirmed text pastes via pbcopy+CGEvent.

**Tech Stack:** sherpa-onnx v1.12.31 XCFramework, Paraformer-zh int8 model (~217MB), Swift 6, AVAudioEngine, CGEvent

---

## Prerequisites

Before starting, download two things manually (the setup script in Task 1 automates this):

1. **XCFramework**: `sherpa-onnx-v1.12.31-macos-xcframework-static.tar.bz2` from GitHub releases
2. **Model**: `sherpa-onnx-paraformer-zh-2024-03-09.tar.bz2` from GitHub releases (for dev testing)

---

## Task 1: Setup sherpa-onnx XCFramework + Build Integration

**Goal:** Get sherpa-onnx compiling with our SPM project via Xcode.

**Files:**
- Create: `scripts/setup.sh` — downloads XCFramework + extracts
- Create: `Sources/CSherpaOnnx/include/module.modulemap` — C module map for SPM
- Create: `Sources/CSherpaOnnx/include/c-api.h` — copy of sherpa-onnx C API header
- Create: `Sources/CSherpaOnnx/shim.c` — empty C file (SPM requires at least one source)
- Create: `Sources/SherpaOnnxSwift/SherpaOnnx.swift` — upstream Swift wrapper (adapted)
- Modify: `Package.swift` — add CSherpaOnnx + SherpaOnnxSwift targets
- Modify: `.gitignore` — ignore Frameworks/ directory

**Step 1: Create setup script**

```bash
#!/bin/bash
# scripts/setup.sh — Download sherpa-onnx XCFramework for macOS
set -euo pipefail

SHERPA_VERSION="v1.12.31"
XCFW_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/${SHERPA_VERSION}/sherpa-onnx-${SHERPA_VERSION}-macos-xcframework-static.tar.bz2"
FRAMEWORKS_DIR="$(cd "$(dirname "$0")/.." && pwd)/Frameworks"

mkdir -p "$FRAMEWORKS_DIR"

if [ -d "$FRAMEWORKS_DIR/sherpa-onnx.xcframework" ]; then
    echo "✅ sherpa-onnx.xcframework already exists"
    exit 0
fi

echo "⬇️  Downloading sherpa-onnx ${SHERPA_VERSION} XCFramework..."
TMPFILE=$(mktemp /tmp/sherpa-onnx-XXXXXX.tar.bz2)
curl -L -o "$TMPFILE" "$XCFW_URL"

echo "📦 Extracting..."
tar xjf "$TMPFILE" -C "$FRAMEWORKS_DIR"
# The archive extracts to a versioned directory — move contents up
EXTRACTED=$(find "$FRAMEWORKS_DIR" -maxdepth 1 -type d -name "sherpa-onnx-*" | head -1)
if [ -n "$EXTRACTED" ] && [ -d "$EXTRACTED/sherpa-onnx.xcframework" ]; then
    mv "$EXTRACTED/sherpa-onnx.xcframework" "$FRAMEWORKS_DIR/"
    rm -rf "$EXTRACTED"
fi

rm -f "$TMPFILE"
echo "✅ sherpa-onnx.xcframework installed to $FRAMEWORKS_DIR/"
```

**Step 2: Create C module for SPM interop**

The XCFramework contains `sherpa-onnx/c-api/c-api.h`. We need to expose it as a C module that Swift can import.

`Sources/CSherpaOnnx/include/module.modulemap`:
```
module CSherpaOnnx {
    header "c-api.h"
    link "sherpa-onnx"
    export *
}
```

`Sources/CSherpaOnnx/shim.c`:
```c
// Empty — required by SPM for C targets
```

Copy `c-api.h` from the XCFramework headers into `Sources/CSherpaOnnx/include/c-api.h`. This header declares all the C functions we need.

**Step 3: Add SherpaOnnx.swift wrapper**

Download from `https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/master/swift-api-examples/SherpaOnnx.swift` and place at `Sources/SherpaOnnxSwift/SherpaOnnx.swift`.

Adapt the file:
- Add `import CSherpaOnnx` at the top
- Remove any bridging header references
- Ensure it compiles with Swift 6 (add `@unchecked Sendable` where needed)

**Step 4: Update Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AzexSpeech",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AzexSpeech", targets: ["AzexSpeech"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        // C API bridge to sherpa-onnx XCFramework
        .systemLibrary(
            name: "CSherpaOnnx",
            path: "Sources/CSherpaOnnx"
        ),
        // Swift wrapper around C API
        .target(
            name: "SherpaOnnxSwift",
            dependencies: ["CSherpaOnnx"],
            path: "Sources/SherpaOnnxSwift"
        ),
        .executableTarget(
            name: "AzexSpeech",
            dependencies: [
                "KeyboardShortcuts",
                "SherpaOnnxSwift",
            ],
            path: "Sources/AzexSpeech",
            resources: [
                .copy("../../Resources/domain-ai.json"),
                .copy("../../Resources/domain-crypto.json"),
            ],
            linkerSettings: [
                .unsafeFlags(["-L", "Frameworks/sherpa-onnx.xcframework/macos-arm64_x86_64"]),
                .linkedLibrary("sherpa-onnx"),
                .linkedLibrary("onnxruntime"),
                .linkedLibrary("c++"),
            ]
        ),
    ]
)
```

> **Note:** The exact linker paths depend on how the XCFramework is structured. May need adjustment after extracting. The key is to link against `libsherpa-onnx.a` and `libonnxruntime.a` from the XCFramework.

**Step 5: Update .gitignore**

Add:
```
Frameworks/
*.xcframework
```

**Step 6: Verify build**

```bash
bash scripts/setup.sh
swift build 2>&1 | head -50
```

Expected: Build succeeds (or identifies specific linking issues to fix). The C module should be importable.

**Step 7: Commit**

```bash
git add scripts/setup.sh Sources/CSherpaOnnx/ Sources/SherpaOnnxSwift/ Package.swift .gitignore
git commit -m "feat(asr): add sherpa-onnx XCFramework integration scaffold"
```

> **⚠️ This task requires iteration.** XCFramework + SPM C interop is finicky. The exact header paths, linker flags, and module map may need adjustment. If SPM won't cooperate, fall back to opening in Xcode and adding the XCFramework manually via the project navigator. The Xcode approach is the officially supported path from sherpa-onnx.

---

## Task 2: Model Download Manager

**Goal:** Download Paraformer-zh model on first launch with progress UI. Models go to `~/Library/Application Support/AzexSpeech/models/asr/`.

**Files:**
- Create: `Sources/AzexSpeech/Services/ModelManager.swift`
- Create: `Sources/AzexSpeech/Views/ModelDownloadView.swift`
- Modify: `Sources/AzexSpeech/App/AppDelegate.swift` — check model on launch

**Step 1: Create ModelManager**

```swift
// Sources/AzexSpeech/Services/ModelManager.swift

import Foundation

/// Manages ASR model download and storage.
/// Models stored at: ~/Library/Application Support/AzexSpeech/models/asr/
@MainActor
final class ModelManager: ObservableObject {
    static let shared = ModelManager()

    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false
    @Published var isModelReady = false
    @Published var error: String?

    private let modelDir: URL
    private var downloadTask: URLSessionDownloadTask?

    // Paraformer-zh int8 model
    static let modelURL = URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-paraformer-zh-2024-03-09.tar.bz2")!
    static let modelDirName = "sherpa-onnx-paraformer-zh-2024-03-09"

    /// Paths to model files (used by SpeechRecognizer)
    var modelPath: String? {
        let path = modelDir.appendingPathComponent(Self.modelDirName).appendingPathComponent("model.int8.onnx").path
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    var tokensPath: String? {
        let path = modelDir.appendingPathComponent(Self.modelDirName).appendingPathComponent("tokens.txt").path
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.modelDir = base.appendingPathComponent("AzexSpeech/models/asr", isDirectory: true)
        try? FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        isModelReady = modelPath != nil
    }

    func downloadModelIfNeeded() async {
        guard !isModelReady, !isDownloading else { return }

        isDownloading = true
        downloadProgress = 0
        error = nil

        do {
            let (tempURL, _) = try await downloadWithProgress(Self.modelURL)
            try extractTarBz2(tempURL, to: modelDir)
            try? FileManager.default.removeItem(at: tempURL)
            isModelReady = true
        } catch {
            self.error = error.localizedDescription
        }

        isDownloading = false
    }

    func cancelDownload() {
        downloadTask?.cancel()
        isDownloading = false
    }

    // MARK: - Private

    private func downloadWithProgress(_ url: URL) async throws -> (URL, URLResponse) {
        let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)
        let totalBytes = response.expectedContentLength
        var data = Data()
        if totalBytes > 0 { data.reserveCapacity(Int(totalBytes)) }

        for try await byte in asyncBytes {
            data.append(byte)
            if totalBytes > 0 {
                downloadProgress = Double(data.count) / Double(totalBytes)
            }
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tar.bz2")
        try data.write(to: tempURL)
        return (tempURL, response)
    }

    private func extractTarBz2(_ archive: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["xjf", archive.path, "-C", destination.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(domain: "ModelManager", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to extract model archive"])
        }
    }
}
```

**Step 2: Create download progress view**

```swift
// Sources/AzexSpeech/Views/ModelDownloadView.swift

import SwiftUI

struct ModelDownloadView: View {
    @ObservedObject var modelManager: ModelManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text("Downloading Speech Model")
                .font(.headline)

            Text("Paraformer-zh (~217 MB)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if modelManager.isDownloading {
                ProgressView(value: modelManager.downloadProgress)
                    .progressViewStyle(.linear)

                Text("\(Int(modelManager.downloadProgress * 100))%")
                    .font(.caption.monospacedDigit())

                Button("Cancel") {
                    modelManager.cancelDownload()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if let error = modelManager.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)

                Button("Retry") {
                    Task { await modelManager.downloadModelIfNeeded() }
                }
            }
        }
        .padding(24)
        .frame(width: 320)
    }
}
```

**Step 3: Wire into AppDelegate — show download window if model missing**

Modify `AppDelegate.swift` to check model readiness on launch:

```swift
// In AppDelegate.applicationDidFinishLaunching:
// After setupStatusBar() and setupHotkey():

if !ModelManager.shared.isModelReady {
    showModelDownloadWindow()
    Task {
        await ModelManager.shared.downloadModelIfNeeded()
        if ModelManager.shared.isModelReady {
            closeModelDownloadWindow()
            initializeEngine()
        }
    }
} else {
    initializeEngine()
}
```

Add a download window using NSWindow + NSHostingView for the ModelDownloadView.

**Step 4: Commit**

```bash
git add Sources/AzexSpeech/Services/ModelManager.swift Sources/AzexSpeech/Views/ModelDownloadView.swift Sources/AzexSpeech/App/AppDelegate.swift
git commit -m "feat(asr): add progressive model download manager with progress UI"
```

---

## Task 3: Speech Recognizer Service (sherpa-onnx Paraformer-zh)

**Goal:** Create a `SpeechRecognizer` that wraps sherpa-onnx offline recognition.

**Files:**
- Create: `Sources/AzexSpeech/Services/SpeechRecognizer.swift`
- Modify: `Sources/AzexSpeech/Services/SpeechEngine.swift` — use SpeechRecognizer

**Step 1: Create SpeechRecognizer**

```swift
// Sources/AzexSpeech/Services/SpeechRecognizer.swift

import Foundation
import SherpaOnnxSwift  // Our Swift wrapper around C API

/// Wraps sherpa-onnx offline Paraformer-zh recognizer.
final class SpeechRecognizer {
    private var recognizer: OpaquePointer?  // SherpaOnnxOfflineRecognizer*
    private(set) var isReady = false

    /// Initialize with model file paths
    func setup(modelPath: String, tokensPath: String) -> Bool {
        // Configure Paraformer model
        var paraformerConfig = SherpaOnnxOfflineParaformerModelConfig(model: toCString(modelPath))

        var modelConfig = SherpaOnnxOfflineModelConfig()
        modelConfig.paraformer = paraformerConfig
        modelConfig.tokens = toCString(tokensPath)
        modelConfig.num_threads = 4
        modelConfig.debug = 0
        modelConfig.provider = toCString("cpu")
        modelConfig.model_type = toCString("paraformer")

        var featConfig = SherpaOnnxFeatureConfig()
        featConfig.sample_rate = 16000
        featConfig.feature_dim = 80

        var config = SherpaOnnxOfflineRecognizerConfig()
        config.model_config = modelConfig
        config.feat_config = featConfig
        config.decoding_method = toCString("greedy_search")

        recognizer = SherpaOnnxCreateOfflineRecognizer(&config)

        if recognizer != nil {
            isReady = true
            return true
        }
        return false
    }

    /// Recognize speech from audio samples.
    /// - Parameter samples: Float32 audio, normalized [-1, 1], 16kHz mono
    /// - Returns: Recognized text, or nil on failure
    func recognize(samples: [Float], sampleRate: Int = 16000) -> String? {
        guard let recognizer, isReady, !samples.isEmpty else { return nil }

        // Create stream
        guard let stream = SherpaOnnxCreateOfflineStream(recognizer) else { return nil }
        defer { SherpaOnnxDestroyOfflineStream(stream) }

        // Feed audio samples
        samples.withUnsafeBufferPointer { ptr in
            SherpaOnnxAcceptWaveformOffline(stream, Int32(sampleRate), ptr.baseAddress, Int32(samples.count))
        }

        // Decode
        SherpaOnnxDecodeOfflineStream(recognizer, stream)

        // Get result
        guard let resultPtr = SherpaOnnxGetOfflineStreamResult(stream) else { return nil }
        defer { SherpaOnnxDestroyOfflineRecognizerResult(resultPtr) }

        let text = String(cString: resultPtr.pointee.text)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    deinit {
        if let recognizer {
            SherpaOnnxDestroyOfflineRecognizer(recognizer)
        }
    }

    // MARK: - Helpers

    /// Convert Swift String to C string pointer that lives long enough.
    /// Uses strdup — caller must manage lifecycle (here: recognizer owns the config).
    private func toCString(_ s: String) -> UnsafePointer<CChar> {
        return UnsafePointer(strdup(s))
    }
}
```

> **⚠️ Note:** The exact C API function names depend on the version of `c-api.h` in the XCFramework. The names above follow the pattern from sherpa-onnx v1.12.x. Adjust if the actual header differs. Key functions: `SherpaOnnxCreateOfflineRecognizer`, `SherpaOnnxCreateOfflineStream`, `SherpaOnnxAcceptWaveformOffline`, `SherpaOnnxDecodeOfflineStream`, `SherpaOnnxGetOfflineStreamResult`.

**Step 2: Modify SpeechEngine to use SpeechRecognizer**

Replace the stub in `SpeechEngine.swift`:

```swift
// In SpeechEngine:
// Add property:
private var recognizer: SpeechRecognizer?
private var accumulatedSamples: [Float] = []

// In initialize():
func initialize() async {
    vocabManager.loadAll()

    // Initialize ASR if model is ready
    if let modelPath = ModelManager.shared.modelPath,
       let tokensPath = ModelManager.shared.tokensPath {
        let rec = SpeechRecognizer()
        if rec.setup(modelPath: modelPath, tokensPath: tokensPath) {
            self.recognizer = rec
            print("✅ Paraformer-zh recognizer ready")
        } else {
            print("⚠️ Failed to initialize Paraformer-zh")
        }
    }

    setupAudioEngine()
}

// In startRecording: reset accumulated samples
func startRecording(onUpdate: @escaping (String) -> Void) {
    guard !isRecording else { return }
    self.onTextUpdate = onUpdate
    self.accumulatedSamples = []
    isRecording = true
    // ... existing audioEngine start code
}

// In the audio tap callback: accumulate samples instead of only ring buffer
// Change the ring buffer write to also accumulate:
if let channelData = converted.floatChannelData {
    let samples = Array(UnsafeBufferPointer(
        start: channelData[0],
        count: Int(converted.frameLength)
    ))
    self.audioBuffer.write(samples)
    if self.isRecording {
        self.accumulatedSamples.append(contentsOf: samples)
    }
}

// In stopRecording: recognize → correct → callback
func stopRecording() {
    guard isRecording else { return }
    isRecording = false
    audioEngine?.stop()

    let samples = accumulatedSamples
    accumulatedSamples = []

    guard !samples.isEmpty else {
        onTextUpdate?("")
        return
    }

    // Run recognition on background thread
    Task.detached { [weak self] in
        guard let self else { return }

        var text: String
        if let recognized = self.recognizer?.recognize(samples: samples) {
            // Post-process with correction engine
            text = self.correctionEngine.correct(recognized)
        } else {
            text = "[ASR not available — download model in Settings]"
        }

        await MainActor.run {
            self.onTextUpdate?(text)
        }
    }
}
```

**Step 3: Verify**

```bash
swift build
```

The recognizer won't work without the model, but it should compile and gracefully fall back to the error message.

**Step 4: Commit**

```bash
git add Sources/AzexSpeech/Services/SpeechRecognizer.swift Sources/AzexSpeech/Services/SpeechEngine.swift
git commit -m "feat(asr): implement Paraformer-zh speech recognition pipeline"
```

---

## Task 4: Floating Panel Edit → Learn Cycle

**Goal:** When user edits text in the floating panel and confirms, extract correction pairs and save to my-vocab.json.

**Files:**
- Modify: `Sources/AzexSpeech/Views/FloatingPanel.swift` — wire edit→learn callback
- Modify: `Sources/AzexSpeech/App/AppDelegate.swift` — connect learning pipeline

**Step 1: Fix FloatingPanel to properly bridge text between NSPanel and SwiftUI**

The current FloatingPanel has a disconnect — `updateText()` writes to `textView` but the SwiftUI content uses its own `@State`. Fix this by using a shared `ObservableObject`:

```swift
// Add to FloatingPanel.swift:

@MainActor
final class FloatingPanelState: ObservableObject {
    @Published var text: String = ""
    @Published var isRecognizing: Bool = true
    var originalASRText: String = ""
}
```

Update `FloatingPanel`:
- Hold a `FloatingPanelState` instance
- Pass it to `FloatingPanelContent` as `@ObservedObject`
- `updateText()` updates `state.text`
- On confirm: callback provides `(original: state.originalASRText, edited: state.text)`

Update `FloatingPanelContent`:
- Accept `@ObservedObject var state: FloatingPanelState`
- Bind TextEditor to `$state.text`
- Show "Listening..." indicator when `state.isRecognizing`

**Step 2: Wire learning in AppDelegate**

```swift
// In toggleRecording() — create panel with onConfirm callback:
floatingPanel = FloatingPanel(onConfirm: { [weak self] original, edited in
    self?.handleConfirmation(original: original, edited: edited)
})

// Add method:
private func handleConfirmation(original: String, edited: String) {
    guard let engine = speechEngine else { return }

    // Extract corrections from user edits
    let corrections = engine.correctionEngine.extractCorrections(
        original: original,
        edited: edited
    )

    // Learn each correction
    for (orig, corrected) in corrections {
        engine.vocabManager.learnCorrection(original: orig, corrected: corrected)
    }

    if !corrections.isEmpty {
        print("📝 Learned \(corrections.count) correction(s)")
    }

    // Paste the confirmed text
    pasteText(edited)
}
```

**Step 3: Commit**

```bash
git add Sources/AzexSpeech/Views/FloatingPanel.swift Sources/AzexSpeech/App/AppDelegate.swift
git commit -m "feat(learn): wire floating panel edit → correction learning cycle"
```

---

## Task 5: pbcopy + CGEvent Paste

**Goal:** Copy confirmed text to clipboard and simulate Cmd+V to paste into the previously focused app.

**Files:**
- Create: `Sources/AzexSpeech/Services/TextPaster.swift`
- Modify: `Sources/AzexSpeech/App/AppDelegate.swift` — call TextPaster from handleConfirmation

**Step 1: Create TextPaster**

```swift
// Sources/AzexSpeech/Services/TextPaster.swift

import AppKit
import Carbon.HIToolbox  // For kVK_ANSI_V

/// Pastes text into the previously focused app via clipboard + Cmd+V.
enum TextPaster {

    /// Copy text to clipboard and simulate Cmd+V paste.
    /// - Parameter text: The text to paste
    /// - Parameter delay: Delay before simulating keypress (seconds).
    ///   Needed to let the floating panel dismiss and focus return to target app.
    static func paste(_ text: String, delay: TimeInterval = 0.05) {
        // 1. Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 2. Small delay for focus to return to target app
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            simulateCmdV()
        }
    }

    // MARK: - Private

    private static func simulateCmdV() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down: Cmd + V
        guard let keyDown = CGEvent(keyboardEventSource: source,
                                     virtualKey: CGKeyCode(kVK_ANSI_V),
                                     keyDown: true) else { return }
        keyDown.flags = .maskCommand

        // Key up: Cmd + V
        guard let keyUp = CGEvent(keyboardEventSource: source,
                                   virtualKey: CGKeyCode(kVK_ANSI_V),
                                   keyDown: false) else { return }
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
```

> **Note:** CGEvent posting requires Accessibility permission. The app should request this on first launch (or it will silently fail). Add a check in AppDelegate with `AXIsProcessTrusted()`.

**Step 2: Wire into AppDelegate**

```swift
// In handleConfirmation(), replace the pasteText() call:
private func handleConfirmation(original: String, edited: String) {
    // ... existing learning code ...

    // Dismiss floating panel first, then paste
    floatingPanel?.dismiss()
    floatingPanel = nil

    guard !edited.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    TextPaster.paste(edited)
}
```

**Step 3: Add Accessibility permission check**

```swift
// In AppDelegate.applicationDidFinishLaunching, add:
private func checkAccessibilityPermission() {
    let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
    if !AXIsProcessTrustedWithOptions(options) {
        print("⚠️ Accessibility permission needed for paste functionality")
    }
}
```

**Step 4: Commit**

```bash
git add Sources/AzexSpeech/Services/TextPaster.swift Sources/AzexSpeech/App/AppDelegate.swift
git commit -m "feat(paste): implement pbcopy + CGEvent Cmd+V text pasting"
```

---

## Task 6: End-to-End Wiring & Polish

**Goal:** Make sure the full pipeline works: hotkey → record → stop → ASR → correct → show in panel → user edits → Enter → paste + learn.

**Files:**
- Modify: `Sources/AzexSpeech/App/AppDelegate.swift` — full pipeline wiring
- Modify: `Sources/AzexSpeech/Views/FloatingPanel.swift` — recording state indicator
- Modify: `Sources/AzexSpeech/Services/SpeechEngine.swift` — expose correctionEngine/vocabManager

**Step 1: Review and fix the full flow**

Ensure AppDelegate orchestrates correctly:

```
1. ⌥Space down → toggleRecording()
   → Create FloatingPanel (show "Listening...")
   → SpeechEngine.startRecording() (accumulates audio)

2. ⌥Space up → stopRecording()
   → SpeechEngine.stopRecording() (recognize → correct → callback)
   → FloatingPanel.updateText(correctedText)
   → Panel becomes editable

3. User edits text in panel

4. Enter → handleConfirmation(original, edited)
   → extractCorrections() → learnCorrection()
   → FloatingPanel.dismiss()
   → TextPaster.paste(editedText)

5. Esc → FloatingPanel.dismiss() (discard)
```

Key things to verify:
- `SpeechEngine.correctionEngine` and `.vocabManager` need to be accessible (change to `internal` access)
- FloatingPanel's SwiftUI content correctly binds to the shared state
- The recording callback properly updates the panel text
- Focus returns to the original app after panel dismissal

**Step 2: Add menu bar recording indicator**

```swift
// In AppDelegate, update status bar icon during recording:
private func updateStatusIcon(recording: Bool) {
    statusItem?.button?.image = NSImage(
        systemSymbolName: recording ? "waveform.circle.fill" : "waveform",
        accessibilityDescription: "Azex Speech"
    )
}
```

Call `updateStatusIcon(recording: true)` when starting and `updateStatusIcon(recording: false)` when stopping.

**Step 3: Commit**

```bash
git add -A
git commit -m "feat(pipeline): wire end-to-end speech recognition pipeline"
```

---

## Execution Notes

### Build System Reality Check

The biggest risk in Phase 1 is **Task 1** — sherpa-onnx XCFramework + SPM integration. sherpa-onnx does not officially support SPM. If the C module approach doesn't work:

**Fallback plan:** Switch to Xcode project-based build.
1. Open `Package.swift` in Xcode
2. Drag `sherpa-onnx.xcframework` into the project navigator
3. Add bridging header: `#import "sherpa-onnx/c-api/c-api.h"`
4. Copy `SherpaOnnx.swift` into `Sources/AzexSpeech/Services/`
5. Build from Xcode instead of `swift build`

This is actually the recommended approach by sherpa-onnx documentation. The SPM approach is ambitious but may require debugging.

### Audio Format Note

The current `SpeechEngine` already outputs 16kHz mono Float32 — which is exactly what sherpa-onnx Paraformer expects. The samples are normalized [-1, 1] from AVAudioEngine. No conversion needed.

The design doc mentions "[-32768, 32767] range (非归一化 float)" — this was an older finding. The current C API (`SherpaOnnxAcceptWaveformOffline`) accepts normalized float [-1, 1].

### Testing Without Model

During development, you can test the pipeline without downloading the 217MB model:
1. The recognizer gracefully returns nil when model is missing
2. The correction engine still works on any text input
3. The floating panel, paste, and learn cycle can be tested with hardcoded text

### Model for Development

For faster iteration, consider using the **small** variant first:
- `sherpa-onnx-paraformer-zh-small-2024-03-09` — only 79MB
- Slightly lower accuracy but much faster to download
- Switch to full model later

---

## Summary

| Task | What | Risk |
|------|------|------|
| 1 | XCFramework + build integration | 🔴 High — C interop with SPM is tricky |
| 2 | Model download manager | 🟢 Low — standard URLSession + tar extraction |
| 3 | SpeechRecognizer + pipeline | 🟡 Medium — depends on Task 1 working |
| 4 | Edit → learn cycle | 🟢 Low — mostly wiring existing code |
| 5 | pbcopy + CGEvent paste | 🟢 Low — proven pattern |
| 6 | End-to-end wiring | 🟡 Medium — integration testing |
