# Twitter/X Thread Drafts

## Thread 1 (English)

**Tweet 1**:
I built a voice input tool for devs who don't speak perfect English.

If you work in Crypto or AI and constantly say terms like "EigenLayer," "DeFi," or "Paraformer" -- but your accent makes every ASR tool butcher them -- this is for you.

Open source, runs locally on Mac. Here's how it works:

**Tweet 2**:
The problem: existing voice input tools assume you speak standard English (or standard Chinese).

But millions of tech workers code-switch constantly -- Chinese sentence, English technical term, back to Chinese. No ASR model handles this well out of the box.

**Tweet 3**:
The fix isn't better models. It's smarter post-processing.

Azex Speech uses a four-layer correction pipeline:

Layer 1: Personal vocab (your accent map)
Layer 2: Context words (from your active window)
Layer 3: Domain dictionaries (Crypto + AI terms)
Layer 4: Calibration (bootstraps your profile)

**Tweet 4**:
The coolest part: it reads your screen.

If you're browsing DeFiLlama, the app extracts terms like "TVL," "Solana," "$ETH" from the active window via macOS Accessibility API.

When you say those terms, it knows what you mean -- even if your pronunciation isn't textbook.

**Tweet 5**:
Tech stack:
- Swift 6 + SwiftUI (native Mac menu bar app)
- sherpa-onnx + Paraformer-zh for ASR
- Everything runs locally, Apple Silicon optimized
- No cloud, no subscription, no data leaves your machine

Phase 2: local MLX small model for context-aware correction.

**Tweet 6**:
It also learns from you.

Every time you correct the output in the floating panel, that correction becomes a permanent rule. The more you use it, the better it gets at understanding YOUR voice.

Not a neural network "learning" -- just a simple, debuggable correction map.

**Tweet 7**:
MIT license, open source:
https://github.com/azex-ai/speech

Built for Crypto/AI people, but the architecture works for any domain. PRs welcome -- especially for domain dictionaries.

If you deal with technical English as a non-native speaker, give it a try.

**Hashtag suggestions**: #opensource #macOS #ASR #voiceinput #crypto #AI #swift #localfirst #buildinpublic

---

## Thread 2 (Chinese)

**Tweet 1**:
做了一个语音输入工具，专门给英语发音不标准但每天要说英文术语的人用。

你试过对着 Mac 说 "EigenLayer" 然后得到 "衣根 layer" 吗？我受够了。

开源，本地运行，不传数据。说说我的思路：

**Tweet 2**:
核心问题：ASR 模型对标准发音很准，但我们说英文术语时带口音。

解决方案不是换更大的模型，而是在识别后做四层纠正：

个人词库 > 上下文词 > 领域词典 > 校准

每一层都在本地，可解释，可调试。

**Tweet 3**:
最有意思的功能：上下文感知。

App 通过 macOS 无障碍 API 读取你当前窗口的内容，提取专业术语（大驼峰、$TICKER、全大写缩写）。

你在看 DeFiLlama 的时候说 "TVL"，它就知道你说的是 TVL，不是 "TVR"。

**Tweet 4**:
校准流程：第一次启动时，让你朗读一段 Crypto/AI 领域的句子。

系统对比你的 ASR 输出和标准文本，自动生成你的个人发音映射表。

相当于用 30 秒建了一个你的口音 profile。

**Tweet 5**:
技术选型：

- Paraformer-zh（中文+中英混合最强的开源 ASR）
- sherpa-onnx（C++ 推理引擎，Swift 绑定）
- 纯 Swift 6 + SwiftUI，macOS 原生
- Apple Silicon 优化，本地推理

Phase 2 会加 MLX 小模型做上下文纠正。

**Tweet 6**:
还有一个设计决策值得分享：

Paraformer 的热词注入（SeACo-CTC）其实不兼容 Paraformer 架构本身。所以后处理替换不是妥协，是正确的技术路线。

简单的方案往往是对的方案。

**Tweet 7**:
MIT 开源：https://github.com/azex-ai/speech

Crypto 和 AI 词典已经内置了几百个术语。欢迎 PR 补充。

如果你也是英语非母语但每天要说英文技术词的人，试试看，给我反馈。

**Hashtag suggestions**: #开源 #macOS #语音输入 #Crypto #AI #Swift #本地优先 #独立开发
