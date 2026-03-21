# Phase 2: App Shell + Onboarding — Design Document

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform Azex Speech from a minimal menu bar stub into a polished macOS app with sidebar navigation, dashboard, vocab management, session history, feed system, and onboarding flow.

**Architecture:** NSPopover from menu bar icon hosts a SwiftUI NavigationSplitView (sidebar + detail). Onboarding is a separate NSWindow shown on first launch. All data is local JSON files. Deep dark theme following Apple HIG.

**Tech Stack:** Swift 6, SwiftUI, NavigationSplitView, KeyboardShortcuts, NSPopover, AXUIElement API

---

## 1. App Shell

### Window Model

Menu bar popover mode. Clicking the waveform icon in menu bar opens an NSPopover containing the full app UI. Clicking outside dismisses it. Voice input still triggers via hotkey → floating panel (independent of main popover).

Popover size: ~720w × 560h (comfortable for sidebar + content).

### Sidebar Navigation

Left sidebar (~200px) with AZEX logo at top, navigation items below:

| Icon | Label | Description |
|------|-------|-------------|
| chart.bar | Dashboard | Usage stats, time saved, words generated |
| clock.arrow.circlepath | History | Session log with original → corrected text |
| book | Vocabulary | Personal + domain vocab, editable |
| text.badge.plus | Feed | Captured text sources + extracted hotwords |
| waveform.badge.mic | Calibration | Read-aloud calibration, can re-enter anytime |
| gear | Settings | Hotkey, domain, model management, about |

### Visual Style

- **Dark theme only** (target audience: developers)
- Background: `.black.opacity(0.9)` with `.ultraThinMaterial` for sidebar
- Accent: single blue tone (`Color.accentColor`)
- Color palette: zinc/neutral grays for text hierarchy
- SF Symbols for all icons
- SF Mono / system monospaced for recognition text, stats numbers
- Rounded corners on cards, subtle borders (`.quaternary`)

### Logo

AZEX round logo (black circle, white "AZEX" text) at:
- `Resources/azex-logo.png` (from `/Users/aaron/Desktop/Logos/AZ-icon/Pngs/AZ-logo-b-512x512.png`)
- Displayed at 32×32 in sidebar header, 64×64 in onboarding

---

## 2. Dashboard

### Stats Cards (top row)

| Metric | Calculation | Display |
|--------|-------------|---------|
| Total Characters | Sum of all confirmed text lengths from history | "12,847 字" |
| Time Saved | total_chars / 30 chars per minute (Chinese typing avg) | "~7.1 小时" |
| Words Learned | Count of personal vocab entries | "43 个" |
| Today's Sessions | Count of today's history entries | "17 次" |

### Activity Chart (optional, v2.1)

Weekly bar chart of daily session counts. Can be deferred — stats cards are enough for v2.

### Stats Persistence

Store in `~/Library/Application Support/AzexSpeech/stats.json`:
```json
{
  "total_characters": 12847,
  "total_sessions": 156,
  "first_use_date": "2026-03-21"
}
```

Updated on every confirmed text paste. Time saved is calculated on-the-fly from total_characters.

---

## 3. History

### Data Model

Stored per-day in `~/Library/Application Support/AzexSpeech/history/YYYY-MM-DD.json`:

```json
{
  "entries": [
    {
      "id": "uuid",
      "timestamp": "2026-03-21T10:30:15",
      "original": "可劳德发布了新的模型",
      "corrected": "Claude 发布了新的模型",
      "learned": [["可劳德", "Claude"]],
      "duration_ms": 3200,
      "char_count": 12
    }
  ]
}
```

### UI

- Left: scrollable list of entries grouped by date, showing time + preview
- Right: detail view with original (red strikethrough) → corrected (bold) diff display
- Search bar at top (filters by text content)
- Uses local computer time for all timestamps

---

## 4. Vocabulary

### UI

- Tab switcher: Personal / Crypto / AI
- Table: Source Word → Correction, with source tag (manual / learned / calibration)
- Inline editing: click a row to edit
- Add button: manually add new correction pair
- Delete: swipe or delete key
- Search/filter bar

### Data

Same JSON files as Phase 1 (`my-vocab.json`, `domain-crypto.json`, `domain-ai.json`). No schema change needed.

---

## 5. Feed (Context Sources)

### Quick Capture (⌥⇧Space)

- Grab active window text via AXUIElement API
- Extract proper nouns (capitalized words, CamelCase, $-prefixed tokens)
- Store in `~/Library/Application Support/AzexSpeech/feed/captures.json`
- Extracted hotwords auto-added to `contextWords` in VocabManager

### Feed Page UI

- List of captures: timestamp + source app name + preview
- Each capture expandable to show full text + extracted hotwords
- Hotwords shown as tags, toggleable (enable/disable per word)
- Delete captures

### captures.json

```json
{
  "captures": [
    {
      "id": "uuid",
      "timestamp": "2026-03-21T10:45:00",
      "source_app": "Cursor",
      "text": "EigenLayer restaking AVS operator...",
      "hotwords": ["EigenLayer", "restaking", "AVS"]
    }
  ]
}
```

---

## 6. Calibration Module

### Flow

1. Display domain-specific calibration text (based on user's chosen domain)
2. User presses hotkey and reads aloud
3. ASR recognizes → diff against expected text
4. Show report: ✅ correct words / ⚠️ needs learning
5. Auto-generate correction pairs → write to my-vocab.json
6. "Read another passage" / "Done"

### Calibration Texts

Stored in `Resources/calibration-ai.txt`, `Resources/calibration-crypto.txt`, `Resources/calibration-both.txt`.

### Accessible From

- Onboarding Step 3.5 (optional)
- Sidebar "Calibration" (anytime)

---

## 7. Onboarding

### Trigger

First launch: check if `~/Library/Application Support/AzexSpeech/onboarding-complete.json` exists. If not, show onboarding window.

### Steps

**Step 1: Welcome**
- AZEX logo (64×64) centered
- "Azex Speech" title
- "Voice input for Crypto & AI professionals"
- [ 开始设置 ] button

**Step 2: Set Hotkey**
- Title: "设置语音快捷键"
- Simplified keyboard illustration showing macOS keyboard outline
- Right Option key highlighted with breathing/pulse animation
- KeyboardShortcuts.Recorder for custom override
- Hint: "按住此键说话，松开识别"
- Default: right Option key
- [ 下一步 ]

**Step 3: Choose Domain**
- Title: "你主要在哪个领域？"
- Three cards:
  - 🤖 AI — "Claude, GPT, LLM, fine-tuning..."
  - ₿ Crypto — "Solana, DeFi, TVL, staking..."
  - 🤖+₿ Both — "AI + Crypto（推荐）"
- Selection loads corresponding domain vocab

**Step 3.5: Calibration (Optional)**
- Title: "要现在校准语音识别吗？"
- "我们准备了一些领域文本，朗读后可以让识别更准确"
- [ 现在校准 ] → enters calibration flow
- [ 稍后再说 ] → skip, can access from sidebar later

**Step 4: Complete**
- AZEX logo + "一切就绪"
- "按住 [右Option] 开始说话" with key animation
- [ 开始使用 ] → write onboarding-complete.json, close window

### Onboarding Window

Separate NSWindow (not in popover). Centered, ~600×450, no resize. Dark background matching app theme. Dismissed after completion, never shown again.

---

## 8. Settings

### Sections

- **Hotkey**: KeyboardShortcuts.Recorder (already exists, enhance UI)
- **Domain**: Same three-option selector as onboarding, can change anytime
- **Models**: Local ASR model status (Paraformer-zh, size, path). Remote model config placeholder (disabled, "Coming soon")
- **Data**: Path to app data directory, "Open in Finder" button, reset options
- **About**: AZEX logo, version, link to speech.azex.ai

---

## 9. Learning Strategy

- **Silent learning**: User edits in floating panel → diff → auto-write to my-vocab.json (existing behavior, unchanged)
- **Manual feed**: ⌥⇧Space captures window text → extracts hotwords → stored in feed. User can manage in Feed page
- **No interruptions**: Zero toasts, zero confirmation dialogs for learning. Status only visible passively on Dashboard
- **History as signal**: All sessions logged. Dashboard shows aggregate stats. No active prompts

---

## 10. Data Storage Summary

```
~/Library/Application Support/AzexSpeech/
├── my-vocab.json              # Personal vocab (existing)
├── domain-crypto.json         # Domain vocab (existing)
├── domain-ai.json             # Domain vocab (existing)
├── stats.json                 # Aggregate usage stats
├── onboarding-complete.json   # Onboarding state + domain choice
├── history/
│   └── 2026-03-21.json        # Per-day session records
├── feed/
│   └── captures.json          # Captured context sources + hotwords
└── models/
    └── asr/                   # ASR model files (existing)
```

All JSON, no database, human-readable, user can manually edit.
