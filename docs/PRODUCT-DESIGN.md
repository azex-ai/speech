# Azex Speech — 产品设计文档

> 状态: Draft v1
> 日期: 2026-03-21
> 归属: speech.azex.ai (Azex 子产品)

---

## 1. 产品定义

**一句话**: 免费、本地优先的 Mac 语音输入工具，专为 Crypto+AI 从业者设计——内置领域词库，越用越懂你。

**目标用户**: Crypto + AI 领域的中英文混说从业者（开发者、交易员、研究员、创业者）

**不是什么**:
- 不是通用语音助手（不做 Siri 类交互）
- 不是会议转录工具（不做长音频/多人场景）
- 不是输入法（不替换系统输入法，是独立工具）

## 2. 商业模型

```
┌─────────────────────────────────────────────┐
│  Azex Speech（免费，获客层）                   │
│  → 本地 ASR + 领域词库 + 隐式学习            │
│  → 所有核心语音输入功能完全免费               │
├─────────────────────────────────────────────┤
│  增值功能（需 Azex 账户）                     │
│  → 远程 LLM 纠正（上下文深度理解）           │
│  → Skills / AI 助手                          │
│  → 屏幕 OCR 深度分析                         │
│  → 通过 Azex 支付网关充值配置远程模型         │
├─────────────────────────────────────────────┤
│  Azex 支付网关（变现层）                      │
│  → 用户充值购买 LLM API 额度                 │
│  → 仅支持加密货币支付                         │
│  → Azex 赚支付通道流水                       │
└─────────────────────────────────────────────┘
```

**核心逻辑**: 工具免费 → 用户量 → LLM 增值 → Azex 支付变现

## 3. 设计原则

1. **极简** — 下载即用，无配置，无注册。用 1 分钟内理解全部功能
2. **静默学习** — 用户不需要知道系统在学习，只会觉得"越用越准"
3. **本地优先** — 核心功能全部离线可用，音频永远不上传
4. **领域原生** — 不做通用工具，Crypto+AI 是一等公民
5. **无垃圾数据** — 学习记录有意义、可追溯，不堆积无用日志

## 4. 核心架构

```
┌──────────────────────────────────────────────────┐
│                 Azex Speech Mac App               │
├────────────┬─────────────────┬───────────────────┤
│  输入层     │   智能层         │   输出层           │
│            │                 │                   │
│ 麦克风常驻  │ 本地 ASR 引擎    │ 可编辑浮窗         │
│ 全局快捷键  │ 三层词库合并     │ 实时识别显示       │
│ 环形缓冲    │ 上下文纠正引擎   │ 用户编辑→确认      │
│ VAD 检测   │ 隐式学习引擎     │ Enter→粘贴到目标   │
├────────────┴─────────────────┴───────────────────┤
│                   数据层                           │
│                                                   │
│  中心词库 (Crypto+AI, 只读, 每日更新)               │
│  个人纠错 Profile (SQLite, 读写)                    │
│  上下文热词缓存 (内存, 临时)                        │
│  使用统计 (本地, 用户可查看)                        │
├───────────────────────────────────────────────────┤
│                 上下文感知层                        │
│                                                   │
│  L1: 活跃窗口文本 (Accessibility API)              │
│  L2: 应用感知 (当前 App 类别→加载对应权重)          │
│  L3: 屏幕 OCR (Apple Vision, 增值功能)             │
├───────────────────────────────────────────────────┤
│                 增值层 (可选)                       │
│                                                   │
│  远程 LLM 纠正 │ Skills/助手 │ 屏幕 OCR 深度分析  │
│        ↕                                          │
│  speech.azex.ai API ← Azex 支付网关               │
└───────────────────────────────────────────────────┘
```

### 技术选型

| 组件 | 选型 | 理由 |
|------|------|------|
| App 框架 | Swift + SwiftUI | 原生 macOS，系统集成最深 |
| ASR 引擎 | sherpa-onnx (Paraformer-zh int8, ~217MB) | 6万小时中文训练，Swift 绑定，RTF~0.15 |
| 备选 ASR | MLX Qwen3-ASR (参考 voxt) | Apple Silicon 优化，中英混输最强 |
| 纠正模型 | 本地小 LLM (MLX Qwen2.5-0.5B 量化) | Mac 配置高跑得动，比规则替换更智能 |
| 纠正数据 | JSON 文件 (App 工作目录内) | 无数据库，文件即数据，可手动编辑 |
| 窗口文本读取 | SelectedTextKit / AXUIElement | VoiceInk 验证可行 |
| 屏幕 OCR | Apple Vision Framework | 系统原生，免费，无额外模型 |
| 全局快捷键 | KeyboardShortcuts (Sindre Sorhus) | 社区标准库 |
| 文本输入 | pbcopy + CGEvent Cmd+V | 已验证方案，支持中英文 |

> **关键技术发现 (sherpa-onnx 调研)**:
> - SeACo 热词偏置仅支持 Transducer 模型，Paraformer 不支持
> - Paraformer 输入需要 [-32768, 32767] 范围（非归一化 float）
> - Apple Silicon RTF: 完整模型 int8 ~0.15, 小模型 ~0.076
> - Swift 集成: XCFramework 静态库 + Bridging Header + SherpaOnnx.swift

## 5. 词库系统（纯本地，无数据库）

> **设计原则**: 所有数据都是 App 工作目录下的 JSON 文件。无 SQLite，无服务端租户。
> Mac 配置高，跑本地 0.5B 量化小模型做纠正，比死规则更智能。

### 工作目录

```
~/Library/Application Support/AzexSpeech/
├── my-vocab.json         # 个人词库（校准生成 + 编辑行为增量）
├── domain-crypto.json    # Crypto 领域词库（内置，可云端刷新）
├── domain-ai.json        # AI 领域词库（内置，可云端刷新）
└── models/
    └── correction/       # 本地纠正小模型（MLX 量化, ~300MB）
```

### 纠正流水线

```
用户说话
  → ASR (Paraformer-zh) 原始输出:
    "可劳德发布了新的模型衣根layer的TVR超过了"
  → 本地小模型纠正 (Qwen2.5-0.5B MLX):
    输入: ASR文本 + 个人词库 + 领域词库 + 上下文词
    Prompt: "修正语音识别错误词汇，参考词库"
    输出: "Claude 发布了新的模型 EigenLayer 的 TVL 超过了"
  → 显示到可编辑浮窗
  → 用户确认或修改 → 更新 my-vocab.json
```

小模型优于规则替换: 理解上下文，处理模糊匹配（空格、连写），Mac M 系列 <500ms。

### 个人词库 (my-vocab.json)

```json
{
  "domain": "ai+crypto",
  "calibrated_at": "2026-03-21T10:30:00",
  "corrections": {
    "可劳德": "Claude",
    "di ploy": "deploy",
    "衣根layer": "EigenLayer",
    "TVR": "TVL"
  }
}
```

来源: 校准阶段批量生成 + 日常编辑增量追加。文件实时读取，改了立即生效。

### 领域词库 (domain-*.json, 内置 + 可选云端同步)

```json
{
  "version": "2026-03-21",
  "category": "crypto",
  "corrections": {
    "衣根layer": "EigenLayer", "uni swap": "Uniswap",
    "深seek": "DeepSeek", "可劳德": "Claude"
  }
}
```

- **v1 内置**: App Bundle 自带，跟 App 版本更新
- **可选云端同步**: 用户点"刷新词库" → 从 speech.azex.ai 拉最新 JSON 覆盖本地
- 云端只是一个 JSON 文件托管，不需要租户系统

### 上下文词 (内存，临时)

```
AX API → 活跃窗口专有名词 → 传入小模型 prompt → 窗口切换时重算
```

## 6. 核心交互流程

### 6.1 日常使用

```
1. ⌥Space (全局快捷键)
   → 光标旁弹出半透明浮窗
   → 麦克风从环形缓冲无缝切换到录音

2. 说话中
   → 浮窗实时显示 ASR 文本 (<0.5s 延迟)
   → 三层词库加持识别
   → 上下文感知辅助

3. 说完 / 再按 ⌥Space
   → 识别完成
   → 浮窗文本变为可编辑状态
   → 用户可修改错误词汇

4. Enter
   → 文本粘贴到目标位置
   → 浮窗消失

5. 后台静默
   → diff(原始识别, 用户修改) → 更新纠错 profile
   → 下次同样发音 → 直接输出正确结果
```

### 6.2 首次校准 (Onboarding)

```
Step 1: 选择领域
  ┌──────────┐ ┌──────────┐ ┌──────────┐
  │  🤖 AI   │ │  ₿ Crypto│ │ 🤖+₿ 两者│
  └──────────┘ └──────────┘ └──────────┘
  可跳过，不强制。无需注册。

Step 2: 朗读校准文本 (~30秒)
  屏幕显示中英混合领域文本
  用户按快捷键朗读 → ASR 实时转录

Step 3: 即时校准报告
  ✅ 识别正确: Anthropic, Solana, Cursor
  ⚠️ 需要学习: Claude→"可劳德", TVL→"TVR"
  已自动添加 N 条纠正规则 ✓
  [ 开始使用 ]  [ 再读一段 ]
```

**校准文本示例 (AI+Crypto 混合)**:
> "最近 Anthropic 发布了 Claude 4.5，在 Solana 生态中，
> Jupiter 的 TVL 超过了 2B。我用 Cursor 部署了一个
> EigenLayer 的 restaking 合约，latency 控制在 200ms 以内。
> DeepSeek 的推理能力在 agentic workflow 场景下表现不错，
> 但 Uniswap V4 的 hook 机制才是真正的创新。"

### 6.3 隐式学习（文件级，无数据库）

```
用户在浮窗编辑
  → diff(ASR原始, 用户修改)
  → 提取被替换的词对: "可劳德" → "Claude"
  → 追加到 my-vocab.json 的 corrections 字段
  → 下次 ASR 输出经过小模型纠正时，词库已包含这条映射
```

**学习即写文件** — 用户改了一个词，my-vocab.json 就多一行。
小模型每次纠正时读取最新词库，自然就"学会"了。
没有置信度、没有衰减、没有复杂逻辑。

**不记录的情况**:
- 用户只是删了几个字（说多了，不是识别错）
- 整句重写（编辑距离 > 80%）
- 识别文本 < 2 字

## 7. 上下文感知系统

### L1: 活跃窗口文本 (免费)

```
Accessibility API → 读取当前焦点窗口的可见文本
  → 提取专有名词 (大写开头、CamelCase、$符号)
  → 注入为临时热词 (高权重)
  → 窗口切换时重新计算
```

**示例**: 在 Cursor 里打开一个 EigenLayer 项目 → 文件名和代码中的 "EigenLayer", "restake", "AVS" 自动成为高权重热词

### L2: 应用感知 (免费)

```
当前 App       → 加载预设权重
─────────────────────────────────
Cursor/VS Code → 编程术语权重 ↑
Terminal       → CLI 命令权重 ↑
Telegram/Slack → Crypto 社区术语权重 ↑
Claude/ChatGPT → AI 术语权重 ↑
Figma          → 设计术语权重 ↑
```

### L3: 屏幕 OCR (增值功能)

```
Apple Vision Framework → 截取活跃窗口区域
  → OCR 提取所有文本
  → 结合 LLM 理解上下文语义
  → 生成更精准的纠正建议
```

需要 LLM 参与 → 属于增值功能 → 需要 Azex 账户

## 8. 增值功能 → Azex 入口

### 触发点

当用户遇到以下场景时，引导到 Azex:

```
1. 识别不准想用 LLM 纠正
   → "启用 AI 纠正可提升 30% 准确率"
   → "配置远程模型" → 跳转 speech.azex.ai/settings

2. 想用 Skills（如"帮我回复"、"翻译成英文"）
   → "Skills 需要 LLM 支持"
   → "充值" → Azex 支付网关

3. 想用屏幕 OCR 深度分析
   → "高级上下文分析需要 AI 模型"
   → 同上
```

### 集成方式

```
Mac App → speech.azex.ai API (账户、配置、余额)
  → 用户在 Web 端配置模型（Claude/GPT/Gemini/DeepSeek）
  → 用户通过 Azex 加密货币支付充值
  → Mac App 读取配置，调用远程 LLM
```

## 9. Design Challenge — 自我审视

### Challenge 1: 只服务 Crypto+AI 是否太窄？

**决策: 刻意窄**

- 优势: 中心词库精准、校准文本有效、社区口碑传播快（这两个圈子重叠度极高）
- 风险: 天花板有限
- 缓解: 词库是增量的，后续可以扩展（FinTech、Web3、DevOps），但 v1 只做两个垂直领域
- **验证标准**: 1000 DAU 之前不扩品类

### Challenge 2: 隐式学习真的能解决准确率问题吗？

**决策: 隐式学习是辅助，不是银弹**

- 核心准确率靠 ASR 引擎本身（Paraformer-zh / Qwen3-ASR）
- 中心词库解决 80% 的领域词汇问题
- 隐式学习解决剩下 20% 的个人发音习惯
- **最差情况**: 即使学习引擎完全不工作，产品仍然是一个带领域词库的优质语音输入工具

### Challenge 3: 免费工具 → Azex 充值的转化率够吗？

**决策: 接受低转化率，靠量取胜**

- 免费工具的获客成本极低（口碑 + 开发者社区传播）
- 即使只有 5% 用户充值使用 LLM 功能
- 每个 LLM 用户月均消耗 $5-20 → Azex 赚手续费
- **关键指标**: 免费→注册转化率，注册→充值转化率

### Challenge 4: Swift 开发成本高，为什么不用 Electron？

**决策: 原生是核心竞争力**

- Accessibility API 是读取其他 App 文本的唯一可靠方式，Swift 调用最自然
- 闪电说/LazyTyper 用 Electron，用户抱怨内存高、不流畅
- 语音输入工具对延迟极敏感，原生 < Electron
- Apple Vision OCR 只有原生才能用
- **开源参考**: voxt (Swift/MLX) 和 VoiceInk (Swift) 已验证 Swift 方案可行
- **缓解**: Claude Code 可以辅助写 Swift

### Challenge 5: 中英混输是全行业难题，我们凭什么解决？

**决策: 不靠 ASR 解决，靠词库+上下文+学习三层叠加**

- ASR 层: Paraformer-zh（中文最强）+ 后处理词库替换
- 词库层: Crypto+AI 专业术语预置，覆盖 90% 场景
- 上下文层: 窗口文本中的英文名词自动成为热词
- 学习层: 用户修正的中英对照自动积累
- **与竞品区别**: 别人只有 ASR 一层，我们有四层叠加

### Challenge 6: 屏幕 OCR 涉及隐私，用户会信任吗？

**决策: OCR 放增值层，免费功能完全不触碰屏幕截图**

- L1 (Accessibility 读窗口文本) 和 L2 (App 感知) 不截屏，只读文本
- L3 (屏幕 OCR) 明确标注为增值功能，需要用户主动开启
- 所有 OCR 在本地处理 (Apple Vision)，不上传
- 只有 LLM 纠正时才发送文本到远程（用户选择的模型）

## 10. 实施路线图

### Phase 0: 项目骨架 ✅ 已完成 (2026-03-21)

- [x] Swift 6 + SwiftUI Menu Bar App 骨架
- [x] 全局快捷键 (⌥Space) + KeyboardShortcuts
- [x] 音频采集管线 (AVAudioEngine → 16kHz → RingBuffer)
- [x] 可编辑浮窗 (FloatingPanel, NSPanel + SwiftUI)
- [x] 三层词库系统 (VocabManager, 纯 JSON 文件, 无数据库)
- [x] 纠正引擎 Phase 1 (规则替换 + diff 提取 + Levenshtein)
- [x] Crypto + AI 领域词库初始数据 (70+ 条)
- [x] Settings UI (快捷键/词库/关于)
- [x] CLAUDE.md 项目规范
- [x] SPM build 通过

**代码位置**: `/Users/aaron/azex/speech/`

### Phase 1: 核心可用 ✅ 已完成 (2026-03-21)

- [x] 集成 sherpa-onnx Paraformer-zh (XCFramework)
  - int8 量化模型 (~217MB)，setup.sh 一键下载
  - C module + SherpaOnnx.swift 封装，SPM 编译通过
  - 输入: Float32 [-1, 1] 归一化，16kHz mono
  - Apple Silicon RTF ~0.15
- [x] ASR 管线打通: 录音 → Paraformer → 文本
- [x] 词库后处理替换接入 ASR 输出 + 自动句末标点
- [x] 浮窗编辑→学习闭环: 用户改词 → diff → 写入 my-vocab.json
- [x] pbcopy + CGEvent Cmd+V 粘贴到目标窗口
- [x] 渐进式模型下载管理器 + 进度 UI (URLSessionDownloadTask)

### Phase 2: UI + Onboarding + 体验 ✅ 已完成 (2026-03-21)

- [x] App Shell: Menu bar popover + 侧边栏导航 (NavigationSplitView)
- [x] 4 步 Onboarding 引导 (欢迎 → 快捷键 → 领域 → 校准)
  - 键盘示意图 + 右 Option 键高亮脉冲动画
  - 领域选择: AI / Crypto / Both
- [x] Dashboard: 4 个统计卡片 (累计字数、节省时间、已学词汇、今日会话)
  - 节省时间 = 打字时间 - 实际录音时间（真实计算）
  - 最近会话列表内嵌 (可复制、删除、清除确认)
- [x] History: 会话记录按天分组，原始→纠正 diff 对比，学习词对标签
- [x] Vocabulary: 三 tab (Personal/Crypto/AI)，行内编辑、增删、搜索
- [x] Feed: 语料捕获 (AX API 读取活跃窗口文本 → 提取热词)
- [x] Calibration: Flashcard 式校准卡片浏览器
  - 每领域 5 段校准文本，朗读 → ASR → Diff → 自动生成纠正规则
  - 已校准/未校准状态追踪，可重新朗读
- [x] Settings: 快捷键、输入模式、音效、领域、模型状态、数据管理
- [x] 录音状态指示器: 紧凑胶囊 HUD (录音中/识别中/已粘贴)
  - 多屏自动跟随鼠标位置
- [x] 右 Option 键作为默认快捷键 (CGEvent 监听)
- [x] 自动粘贴模式 / 编辑确认模式 (Settings 切换)
- [x] 录音开始/结束音效 (Tink/Hero, 可关闭)
- [x] 废土暖色主题 (AzexTheme: 琥珀橙 #E8853D + 深色)
- [x] GitHub 开源发布: azex-ai/speech, v0.0.1

### Phase 3: 智能纠正 (计划中)

- [ ] 集成 MLX 本地小模型 (Qwen2.5-0.5B 量化, ~200MB)
  - 渐进式下载
  - Mac M 系列 < 500ms 推理
- [ ] 小模型纠正管线: ASR 文本 + 词库 + 上下文 → prompt → 纠正
- [ ] 中间标点自动插入 (逗号、顿号，基于小模型)
- [ ] 领域词库云端刷新 (手动触发, 从 speech.azex.ai 拉 JSON)
- [ ] 应用感知 (L2): 检测当前 App → 调整词库权重

### Phase 4: Azex 集成 (计划中)

- [ ] Azex 账户登录 (speech.azex.ai)
- [ ] 远程 LLM 配置 (Claude/GPT/Gemini/DeepSeek)
- [ ] Azex 支付网关充值入口
- [ ] Skills / AI 助手框架
- [ ] 屏幕 OCR 深度分析 (L3, Apple Vision + LLM)

### 不做 (v1 排除)

- ❌ Windows 版（验证 Mac 后再考虑）
- ❌ 流式识别（离线模式延迟可接受）
- ❌ 服务端租户系统（纯本地）
- ❌ SQLite 数据库（纯 JSON 文件）
- ❌ SeACo 热词偏置（Paraformer 不支持，用后处理替换）

### 成功标准

| 指标 | 目标 |
|------|------|
| 首次识别延迟 | < 1s（松开快捷键到文字出现） |
| 领域词汇识别率 | > 85%（含词库加持） |
| 校准后识别率提升 | > 10%（对比未校准） |
| DMG 安装包大小 | < 20MB（模型首次启动下载） |
| 模型总下载量 | ~280MB (ASR 217MB + 纠正 ~200MB, gzip 后更小) |
| 首次可用时间 | < 3 分钟（下载 ASR 模型后即可用）|

## 11. 竞品对照表（完整版）

详见: [[Mac语音输入App竞品全景调研]]

核心结论:
1. 中英混输是全行业未解难题 → 我们用四层叠加解决
2. 没人做隐式学习 → 我们的核心差异化
3. 可编辑识别窗口是空白 → 我们的交互创新
4. AI纠正vs速度矛盾 → 我们免费层不走LLM，保持速度
5. 隐私vs功能取舍 → 本地优先，OCR 只在增值层

## 12. 开源项目参考

| 项目 | 参考价值 | 协议 |
|------|---------|------|
| voxt | 中文最强 Swift App, MLX Qwen3-ASR, App Branch | Apache 2.0 ✅ |
| VoiceInk | 最成熟 Swift 架构, SelectedTextKit | GPL v3 ⚠️ |
| OpenWhispr | 自动学习词典实现 | MIT ✅ |
| sherpa-onnx | Paraformer-zh + SeACo 热词 + Swift 绑定 | Apache 2.0 ✅ |
| OpenSuperWhisper | 亚洲语言自动纠正 | MIT ✅ |
| super-voice-assistant | Parakeet via FluidAudio 集成参考 | 待确认 |
| voice-input (xuiltul) | **屏幕上下文最佳参考**: AX API 优先 + 截屏 Vision 兜底 | MIT ✅ |

**建议起点**: Fork voxt (Apache 2.0)，集成 sherpa-onnx Paraformer-zh，参考 OpenWhispr 的自动学习词典

## 附录 A: OpenWhispr 自动学习实现参考

> 来源: OpenWhispr v1.6.6 (MIT), 2026-03-19

### 自动学习五步流水线

```
1. captureTargetPid()
   → 按快捷键时记录当前焦点 App 的 PID (osascript JXA)

2. 粘贴识别文本
   → clipboard + CGEvent Cmd+V

3. TextEditMonitor.startMonitoring(originalText, 30000ms)
   → macOS: 编译的 Swift binary (macos-text-monitor.swift)
   → 用 AXObserver + kAXValueChangedNotification 监听文本字段变化
   → 备选: osascript 每 500ms 轮询 AXValue 属性

4. 防抖 1500ms → extractCorrections()
   → 滑动窗口 LCS 定位粘贴文本在字段中的位置
   → 分词 + word-level LCS diff → 找 [原词, 修改词] 对
   → 过滤: 编辑距离比 > 0.65 的跳过（非纠错，是改写）
   → 过滤: 修改词 < 3 字符的跳过
   → 过滤: 已在词典中的跳过
   → 如果 > 50% 的词都变了 → 判定为整句改写，中止学习

5. 持久化
   → SQLite custom_dictionary 表 (word TEXT UNIQUE)
   → IPC 广播 dictionary-updated → 所有窗口同步
   → Toast 提示 "已学习" + 支持撤销
```

### OpenWhispr 的不足（我们要改进的）

| OpenWhispr 现状 | Azex Speech 改进 |
|----------------|-----------------|
| 词典只存 word，无频率/置信度 | correction_log 记录频率+置信度+上下文 |
| 无 LRU/过期机制（社区已提 issue） | 30 天未出现 → confidence 衰减 |
| 全量 DELETE+INSERT 更新 | 增量 UPSERT |
| 词典以逗号拼接为 Whisper initialPrompt | SeACo 热词偏置（权重可调） |
| 只检测替换，不检测删除模式 | 区分「纠错」和「删减」两类编辑行为 |

### 关键 Swift 组件参考

| 文件 | 参考价值 |
|------|---------|
| `macos-text-monitor.swift` | AXObserver 监听文本变化，直接可移植到 Swift App |
| `macos-fast-paste.swift` | CGEvent 粘贴，不需要 Accessibility 权限 |
| `correctionLearner.js` | LCS diff 算法，需要用 Swift 重写 |

## 附录 B: 屏幕上下文实现参考 (voice-input)

> 来源: voice-input (xuiltul), MIT

### 两层方案

```
L1 (优先): AX API 文本提取
  → AXUIElementCreateApplication(frontmostPID)
  → 递归遍历元素树 (深度 15, 上限 500 元素, 200ms 超时)
  → 提取: AXStaticText, AXTextField, AXTextArea, AXLink, AXHeading
  → 如果文本 >= 20 字符 → 直接用作上下文热词

L2 (兜底): 截屏 + Vision LLM
  → osascript 获取前台窗口坐标 → screencapture -x -o -R x,y,w,h
  → base64 → 本地 vision 模型 (qwen3-vl:8b)
  → Prompt: "识别活跃区域并逐字提取文本"
  → 关键: Vision 与 ASR 并行启动，不增加延迟
```

### Azex Speech 适配

- L1 直接用，Swift 调用 AX API 更自然
- L2 改用 Apple Vision Framework (免费) 做 OCR，不需要额外 vision 模型
- L2 深度分析（LLM 理解语义）放增值层

---

> 下一步: 用户确认设计 → 创建 GitHub repo (azex-ai/speech) → worktree 开发
