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
- **ASR Engine**: sherpa-onnx FireRedASR v2 CTC (Chinese-English bilingual SOTA)
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
3. **FireRedASR v2 CTC for ASR** — Chinese-English bilingual SOTA, best code-switching accuracy
4. **Hotwords boosting** — hotwords.txt fed to sherpa-onnx for domain term boosting + post-processing replacement
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

## Completed

- [x] ASR pipeline (FireRedASR v2 CTC, bundled in app, 8 threads)
- [x] Correction engine (3325+ domain terms, rule-based replacement)
- [x] Floating panel edit → learn cycle
- [x] Onboarding calibration flow (flashcard browser)
- [x] Pronunciation training module (history-based, lazy-loaded)
- [x] Model bundled in app (zero download, drag-to-Applications)
- [x] Hotwords engine-level boosting (232 terms)
- [x] DMG packaging (v0.2.0)

## TODO — Next Phase: Cloud Service (speech.azex.ai)

1. [ ] Build speech.azex.ai backend API (Cloud Run + Firestore)
2. [ ] Cloud ASR endpoint (Deepgram Nova-3 for Lite version)
3. [ ] Cloud LLM correction endpoint (GPT-4o-mini)
4. [ ] User auth + Azex account system
5. [ ] Lite client (~10MB, cloud-driven, zero model download)
6. [ ] Settings UI: "智能纠正" toggle + account login
7. [ ] Streaming correction UX (rules first → LLM upgrade)
8. [ ] Payment integration (Stripe + Azex crypto gateway)
9. [ ] Cloud vocab refresh (pull latest terms from API)
10. [ ] AX API context word extraction (send context to cloud)

## Open Source References

- voxt (hehehai/voxt) — Chinese Swift voice app, Apache 2.0
- OpenWhispr (OpenWhispr/openwhispr) — auto-learn dictionary, MIT
- sherpa-onnx (k2-fsa/sherpa-onnx) — ASR inference engine, Apache 2.0
- voice-input (xuiltul/voice-input) — AX API screen context, MIT
