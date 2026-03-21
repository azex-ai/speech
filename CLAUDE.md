# CLAUDE.md — Azex Speech

## Project Overview

Mac native voice input tool for Crypto + AI professionals. Menu bar app with global hotkey, editable floating panel, and implicit learning from user corrections.

**Product**: speech.azex.ai (Azex sub-product)
**Design Doc**: /Users/aaron/PKM/docs/plans/2026-03-21-azex-speech-product-design.md
**Competitive Research**: /Users/aaron/PKM/00-Inbox/26-03-21-Mac语音输入App竞品全景调研.md

## Tech Stack

- **Language**: Swift 6 + SwiftUI
- **Platform**: macOS 14+ (Sonoma), Apple Silicon primary
- **Package Manager**: Swift Package Manager
- **ASR Engine**: sherpa-onnx Paraformer-zh (to be integrated)
- **Correction**: Local small LLM via MLX (Phase 2), rule-based replacement (Phase 1)
- **Audio**: AVAudioEngine, 16kHz mono Float32
- **Hotkeys**: KeyboardShortcuts (Sindre Sorhus)
- **Text Input**: pbcopy + CGEvent Cmd+V

## Architecture

```
Sources/AzexSpeech/
├── App/              # App lifecycle, delegate, hotkey config
├── Views/            # SwiftUI views (floating panel, settings, onboarding)
├── Services/         # Business logic (speech engine, vocab, correction, context)
└── Models/           # Data types (VocabFile, RingBuffer)
```

## Key Design Decisions

1. **No database** — all data is JSON files in ~/Library/Application Support/AzexSpeech/
2. **No server dependency for core features** — everything runs locally
3. **Paraformer-zh for ASR** — best Chinese accuracy, sherpa-onnx Swift bindings
4. **SeACo hotwords don't work with Paraformer** — use post-processing replacement instead
5. **Progressive model download** — thin app install, models downloaded on first launch
6. **Editable floating panel** — user edits = training signal for personal vocab

## Vocab System

Priority: personal > context > domain

- `my-vocab.json` — personal corrections (from calibration + daily edits)
- `domain-crypto.json` — Crypto terms (bundled, refreshable)
- `domain-ai.json` — AI terms (bundled, refreshable)
- Context words — extracted from active window via AX API (in-memory)

## Development

```bash
# Build
swift build

# Run
swift run AzexSpeech

# Open in Xcode (generates .xcodeproj)
open Package.swift
```

## TODO (Priority Order)

1. [ ] Integrate sherpa-onnx Paraformer-zh as SPM dependency or XCFramework
2. [ ] Implement ASR pipeline (audio → Paraformer → text)
3. [ ] Wire correction engine into ASR output
4. [ ] Implement floating panel edit → learn cycle
5. [ ] Build onboarding calibration flow
6. [ ] Add AX API context word extraction
7. [ ] Model download manager (progressive install)
8. [ ] Integrate MLX small model for Phase 2 correction
9. [ ] Cloud vocab refresh from speech.azex.ai
10. [ ] Azex payment gateway integration for LLM features

## Open Source References

- voxt (hehehai/voxt) — Chinese Swift voice app, Apache 2.0
- OpenWhispr (OpenWhispr/openwhispr) — auto-learn dictionary, MIT
- sherpa-onnx (k2-fsa/sherpa-onnx) — ASR inference engine, Apache 2.0
- voice-input (xuiltul/voice-input) — AX API screen context, MIT
