import KeyboardShortcuts
import SwiftUI

struct SettingsMainView: View {
    @State private var selectedDomain = "both"
    @State private var autoPaste = AppSettings.autoPasteMode
    @State private var soundEnabled = AppSettings.soundEnabled
    @State private var modelReady = false
    @State private var modelSize: String = "—"
    @State private var modelPathDisplay: String = "—"

    private let appSupportPath: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("AzexSpeech", isDirectory: true)
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hotkey
                settingsSection("快捷键", systemImage: "command") {
                    KeyboardShortcuts.Recorder("录音快捷键", name: .toggleRecording)
                    Text("按一下开始录音，再按一下完成识别")
                        .font(.caption)
                        .foregroundStyle(AzexTheme.textSecondary)
                }

                sectionDivider()

                // Input mode
                settingsSection("输入模式", systemImage: "keyboard") {
                    Toggle("自动粘贴", isOn: $autoPaste)
                        .foregroundStyle(AzexTheme.textPrimary)
                        .onChange(of: autoPaste) { _, newValue in
                            AppSettings.autoPasteMode = newValue
                        }
                    Text(autoPaste
                        ? "识别完成后直接粘贴到当前窗口"
                        : "识别完成后弹出编辑窗口，确认后粘贴")
                        .font(.caption)
                        .foregroundStyle(AzexTheme.textSecondary)
                }

                sectionDivider()

                // Sound
                settingsSection("音效", systemImage: "speaker.wave.2") {
                    Toggle("录音提示音", isOn: $soundEnabled)
                        .foregroundStyle(AzexTheme.textPrimary)
                        .onChange(of: soundEnabled) { _, newValue in
                            AppSettings.soundEnabled = newValue
                        }
                    Text("开始和结束录音时播放提示音")
                        .font(.caption)
                        .foregroundStyle(AzexTheme.textSecondary)
                }

                sectionDivider()

                // Domain
                settingsSection("领域", systemImage: "globe") {
                    Picker("当前领域", selection: $selectedDomain) {
                        Text("AI").tag("ai")
                        Text("Crypto").tag("crypto")
                        Text("Both").tag("both")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedDomain) { _, newValue in
                        saveDomainSetting(newValue)
                    }
                }

                sectionDivider()

                // Local model
                settingsSection("本地模型", systemImage: "cpu") {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(modelReady ? AzexTheme.success : AzexTheme.error)
                            .frame(width: 8, height: 8)
                        Text("FireRedASR2 CTC")
                            .foregroundStyle(AzexTheme.textPrimary)
                        Spacer()
                        Text(modelReady ? "就绪" : "未下载")
                            .foregroundStyle(AzexTheme.textSecondary)
                    }

                    if modelReady {
                        LabeledContent("路径") {
                            Text(modelPathDisplay)
                                .fontDesign(.monospaced)
                                .foregroundStyle(AzexTheme.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .font(.caption)
                        .foregroundStyle(AzexTheme.textSecondary)

                        LabeledContent("大小") {
                            Text(modelSize)
                                .foregroundStyle(AzexTheme.textSecondary)
                        }
                        .font(.caption)
                        .foregroundStyle(AzexTheme.textSecondary)
                    }
                }

                sectionDivider()

                // Remote model
                settingsSection("远程模型", systemImage: "cloud") {
                    Text("Coming Soon — 配置远程 LLM 纠正模型")
                        .foregroundStyle(AzexTheme.textSecondary)
                }

                sectionDivider()

                // Data
                settingsSection("数据", systemImage: "folder") {
                    LabeledContent("存储位置") {
                        Text(appSupportPath.path)
                            .fontDesign(.monospaced)
                            .foregroundStyle(AzexTheme.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .font(.caption)
                    .foregroundStyle(AzexTheme.textSecondary)

                    HStack {
                        Button("在 Finder 中打开") {
                            NSWorkspace.shared.open(appSupportPath)
                        }
                        Button("导出词库") {
                            exportVocabulary()
                        }
                    }
                }

                sectionDivider()

                // About
                settingsSection("关于", systemImage: "info.circle") {
                    HStack(spacing: 12) {
                        LogoImage(size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Azex Speech v0.1.0")
                                .foregroundStyle(AzexTheme.textPrimary)
                            Link("speech.azex.ai", destination: URL(string: "https://speech.azex.ai")!)
                                .font(.caption)
                                .foregroundStyle(AzexTheme.accent)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AzexTheme.bg)
        .onAppear {
            loadDomainSetting()
            checkModelStatus()
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AzexTheme.textTertiary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionDivider() -> some View {
        AzexTheme.border
            .frame(height: 1)
    }

    // MARK: - Domain persistence

    private func loadDomainSetting() {
        let path = appSupportPath.appendingPathComponent("onboarding-complete.json")
        guard let data = try? Data(contentsOf: path),
              let state = try? JSONDecoder().decode(OnboardingState.self, from: data)
        else { return }
        selectedDomain = state.domain
    }

    private func saveDomainSetting(_ domain: String) {
        let path = appSupportPath.appendingPathComponent("onboarding-complete.json")

        // Load existing state, update domain
        var state: OnboardingState
        if let data = try? Data(contentsOf: path),
           let existing = try? JSONDecoder().decode(OnboardingState.self, from: data)
        {
            state = existing
        } else {
            state = OnboardingState(completed: true, domain: domain)
        }
        state.domain = domain

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(state) {
            try? data.write(to: path, options: .atomic)
        }
    }

    // MARK: - Model status

    private func checkModelStatus() {
        // Check bundle first (production), then app support (dev)
        if let modelURL = Bundle.module.url(forResource: "model.int8", withExtension: "onnx") {
            modelReady = true
            modelPathDisplay = modelURL.deletingLastPathComponent().path

            if let attrs = try? FileManager.default.attributesOfItem(atPath: modelURL.path),
               let size = attrs[.size] as? UInt64
            {
                modelSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            }
            return
        }

        let base = appSupportPath.appendingPathComponent("models/asr/sherpa-onnx-fire-red-asr2-ctc-zh_en-int8-2026-02-25")
        let modelFile = base.appendingPathComponent("model.int8.onnx")
        let fm = FileManager.default

        if fm.fileExists(atPath: modelFile.path) {
            modelReady = true
            modelPathDisplay = base.path

            if let attrs = try? fm.attributesOfItem(atPath: modelFile.path),
               let size = attrs[.size] as? UInt64
            {
                modelSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            }
        } else {
            modelReady = false
            modelPathDisplay = base.path
        }
    }

    // MARK: - Export

    private func exportVocabulary() {
        let source = appSupportPath.appendingPathComponent("my-vocab.json")
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let dest = downloads.appendingPathComponent("my-vocab.json")

        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: source, to: dest)

        // Reveal in Finder
        NSWorkspace.shared.selectFile(dest.path, inFileViewerRootedAtPath: "")
    }
}
