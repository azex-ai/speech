# Reddit Post Drafts

## r/macapps

**Title**: Azex Speech -- native macOS voice input with domain-specific vocabulary correction (open source)

**Body**:

I've been frustrated with voice input on Mac for a while. I work in tech and constantly mix English technical terms with Chinese. Apple Dictation doesn't handle mixed-language input well, and third-party tools either require a subscription or send audio to the cloud.

I built Azex Speech as a menu bar app with these design goals:

- **Fully native**: Swift 6 + SwiftUI, feels like a system app
- **100% local**: ASR runs on-device via sherpa-onnx, no cloud dependency
- **Global hotkey**: Press right Option to start/stop recording (configurable)
- **Editable floating panel**: Shows transcription result, you edit it, then it pastes into whatever app you're in via Cmd+V
- **Learns from corrections**: Every edit you make in the floating panel gets saved as a personal correction rule

The app uses Paraformer-zh for speech recognition, which handles Chinese and Chinese-English mixing well. On top of that, there's a four-layer correction system (personal > context > domain dictionaries) that fixes technical terms the ASR model gets wrong.

macOS 14+ (Sonoma), Apple Silicon primary. Open source under MIT: https://github.com/azex-ai/speech

Would love to hear if others have similar needs around domain-specific voice input on Mac.

---

## r/CryptoCurrency

**Title**: Built an open-source voice input tool with a built-in Crypto dictionary -- finally stops turning "EigenLayer" into gibberish

**Body**:

Quick context: I spend a lot of time in Crypto (research, writing, Discord/Telegram) and I'm not a native English speaker. Voice input should save time, but every tool I've tried turns Crypto terms into nonsense. "DeFi" becomes "deep fi," "Uniswap" becomes "uni swap," "Solana" becomes "索拉那" (a Chinese transliteration).

I put together a macOS voice input tool called Azex Speech that ships with a Crypto domain dictionary -- hundreds of pre-mapped corrections for terms like:

- Bitcoin, Ethereum, Solana, Arbitrum, EigenLayer
- DeFi, TVL, MEV, restaking
- Uniswap, Aave, Jupiter, CoinGecko, DeFiLlama
- Ticker symbols and protocol names

It also reads your active window (e.g., if you're on DeFiLlama or looking at a $SOL chart) and uses those terms as context hints for better recognition.

Everything runs locally on your Mac -- no audio goes to any server. The correction dictionary is open source, so the community can contribute terms.

MIT license: https://github.com/azex-ai/speech

Not trying to sell anything -- it's free and open source. Sharing in case others have the same pain point. PRs welcome if you want to add terms to the Crypto dictionary.

---

## r/LocalLLaMA

**Title**: Local ASR + post-processing correction pipeline for domain-specific vocabulary (sherpa-onnx + planned MLX integration)

**Body**:

Sharing an approach I've been working on for domain-specific voice input that runs entirely locally.

**The problem**: Off-the-shelf ASR models (Whisper, Paraformer, etc.) struggle with specialized vocabulary -- Crypto terms, AI jargon, mixed-language input. Fine-tuning is expensive and doesn't generalize.

**The approach**: Instead of fine-tuning the ASR model, I run Paraformer-zh via sherpa-onnx for base recognition, then apply a four-layer post-processing correction pipeline:

1. **Personal vocab** (highest priority) -- learned from user corrections, essentially a personal accent map
2. **Context words** -- extracted in real-time from the active window via macOS Accessibility API (picks up CamelCase, $TICKERS, ALL_CAPS)
3. **Domain dictionaries** -- bundled correction maps for Crypto and AI terminology
4. **Calibration** -- initial session where user reads domain sentences, system diffs ASR output against expected text to bootstrap personal vocab

The key technical insight: Paraformer's built-in hotword mechanism (SeACo-CTC) doesn't work with the Paraformer architecture itself. So post-processing is actually the correct approach, not a workaround.

**Phase 2 plan**: Integrate a local small LLM via MLX (thinking Qwen2.5-0.5B) for context-aware correction that goes beyond simple string replacement. The model would see the ASR output + context words and produce corrected text. Still fully local.

This is built as a macOS app (Swift 6, Apple Silicon optimized), but the correction pipeline pattern could work with any ASR backend. Open source under MIT: https://github.com/azex-ai/speech

Questions for the community:
- Has anyone experimented with small LLMs for ASR post-processing correction?
- Any experience with MLX for real-time inference in a desktop app context?
- Better model suggestions than Qwen2.5-0.5B for this use case?

---

## r/ChineseLanguage

**Title**: Built a voice input tool for Chinese-English mixed speech -- handles code-switching without manual language toggle

**Body**:

If you speak Chinese but regularly use English technical terms (common in tech, finance, academia), you've probably experienced the voice input dilemma: Chinese input mode mangles English words, English mode can't handle Chinese, and manually switching between them defeats the purpose of voice input.

I built a macOS voice input tool that handles Chinese-English code-switching natively. It uses Paraformer-zh, an ASR model specifically trained on Chinese and mixed Chinese-English speech. On top of that, there's a correction layer that maps common recognition errors to the right terms.

For example, when I say a sentence mixing Chinese and English:

- "衣太坊" (yi tai fang, how Chinese speakers often say Ethereum) -> automatically corrected to "Ethereum"
- "索拉那" (suo la na, Chinese phonetic approximation of Solana) -> "Solana"
- Natural Chinese sentences pass through unchanged

The app also has a calibration feature where you read sample sentences in your natural speaking style, and it learns your specific pronunciation patterns for English terms.

Everything runs locally on Mac, no internet needed. MIT open source: https://github.com/azex-ai/speech

This is primarily built for Crypto/AI professionals, but the correction system works for any domain. If there's interest, I'd love to add dictionaries for other fields (academic, medical, legal).

Has anyone found other tools that handle Chinese-English code-switching well? Would be curious to compare approaches.
