# Show HN: Azex Speech -- macOS Voice Input for Non-Native English Speakers in Crypto/AI

**Title**: Show HN: Azex Speech -- macOS voice input that learns your accent for Crypto/AI terms

**Post body**:

I work in Crypto and AI. My native language is Chinese, but I spend all day talking about Ethereum, EigenLayer, DeFi, and LLM architectures. Every voice input tool I've tried butchers these terms -- Apple Dictation turns "EigenLayer" into random syllables, Whisper-based tools get close but still miss domain-specific vocabulary, and nothing handles Chinese-English code-switching well.

So I built Azex Speech, a macOS menu bar app that does local speech recognition with a four-layer correction system designed specifically for non-native speakers working with English technical terms:

1. **Personal vocab** -- When you correct the floating panel output, the app learns your specific pronunciation patterns. Say "衣根layer" and it maps to "EigenLayer" forever.
2. **Context-aware hotwords** -- The app reads the active window via macOS Accessibility API and extracts technical terms (CamelCase, $-prefixed tickers, ALL_CAPS acronyms). If you're on DeFiLlama, it knows to expect "TVL" and "Solana."
3. **Domain dictionaries** -- Bundled Crypto and AI term dictionaries with hundreds of corrections for common ASR mistakes on technical vocabulary.
4. **Calibration** -- First-launch onboarding reads you domain-specific sentences, compares ASR output to expected text, and generates your personal correction map upfront.

Under the hood: sherpa-onnx with Paraformer-zh for ASR (best open-source model for Chinese + mixed Chinese-English), Swift 6 + SwiftUI, everything runs locally on Apple Silicon. No cloud, no subscription, no data leaving your machine. Phase 2 will add a local MLX small model (Qwen2.5-0.5B) for context-aware correction beyond simple replacement.

The key insight is that Paraformer's hotword injection (SeACo-CTC) doesn't actually work with the Paraformer architecture, so instead of fighting the model, we do post-processing replacement with prioritized vocab layers. It's simpler and works surprisingly well.

Open source, MIT license: https://github.com/azex-ai/speech

I'd love feedback on the approach. Has anyone else dealt with domain-specific vocabulary in local ASR? Curious if there are better strategies than post-processing replacement.
