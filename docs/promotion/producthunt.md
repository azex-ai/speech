# Product Hunt Launch Draft

## Tagline (60 chars max)

```
Voice input for Mac that learns your accent and jargon
```
(55 characters)

## Description (260 chars max)

```
macOS voice input for non-native English speakers in Crypto & AI. Four-layer correction learns your pronunciation, reads screen context, and ships with domain dictionaries. Runs 100% locally on Apple Silicon. Open source.
```
(222 characters)

## Topics

- macOS
- Developer Tools
- Artificial Intelligence
- Productivity
- Open Source

## Gallery images

1. Hero image: App icon + tagline on dark background
2. Screenshot: Floating panel showing correction in action
3. Screenshot: Dashboard with usage stats
4. Screenshot: Vocabulary management view
5. Diagram: Four-layer correction system architecture

## Maker Comment Draft

Hey Product Hunt!

I'm a developer working in Crypto and AI, and my native language is Chinese. I spend all day talking about Ethereum, EigenLayer, DeFi -- but every voice input tool turns these into gibberish because my pronunciation isn't textbook English.

So I built Azex Speech. The core idea: instead of trying to fine-tune an ASR model (expensive, doesn't generalize), run a good base model (Paraformer-zh via sherpa-onnx) and apply smart post-processing correction.

The four correction layers:

1. **Personal vocab** -- learns from your edits. Every correction you make becomes a permanent rule.
2. **Screen context** -- reads your active window via macOS Accessibility API, extracts technical terms as recognition hints.
3. **Domain dictionaries** -- ships with Crypto and AI term databases (hundreds of corrections).
4. **Calibration** -- 30-second onboarding where you read domain sentences, system builds your accent profile.

Everything runs locally. No audio leaves your Mac. No subscription. No cloud dependency.

It's open source (MIT) and I'd love feedback -- especially from other non-native English speakers who work with technical vocabulary daily.

GitHub: https://github.com/azex-ai/speech

## First Day Strategy

- Launch on Tuesday or Wednesday (best PH days)
- Post at 00:01 PST (start of the PH day)
- Share on Twitter, V2EX, and relevant communities same day
- Respond to every comment within 1 hour
- Have GIF demos ready showing before/after correction
