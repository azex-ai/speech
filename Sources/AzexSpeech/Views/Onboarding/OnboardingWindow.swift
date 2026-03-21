import KeyboardShortcuts
import SwiftUI

struct OnboardingContentView: View {
    var onComplete: () -> Void

    @State private var currentStep = 0
    @State private var selectedDomain = "both"
    @State private var logoAppeared = false
    @State private var menuBarArrowVisible = false

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            ZStack {
                switch currentStep {
                case 0:
                    welcomeStep
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case 1:
                    hotkeyStep
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case 2:
                    domainStep
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case 3:
                    calibrationStep
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case 4:
                    completeStep
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // Step indicator dots
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Circle()
                        .fill(dotIndex(for: currentStep) == index ? AzexTheme.accent : AzexTheme.textTertiary)
                        .frame(width: dotIndex(for: currentStep) == index ? 8 : 6,
                               height: dotIndex(for: currentStep) == index ? 8 : 6)
                        .animation(.spring(response: 0.3), value: currentStep)
                }
            }
            .padding(.bottom, 20)
        }
        .frame(width: 560, height: 420)
        .background(AzexTheme.bg)
        .preferredColorScheme(.dark)
    }

    /// Map step number to dot index (step 3 calibration shares dot with step 2)
    private func dotIndex(for step: Int) -> Int {
        switch step {
        case 0: return 0
        case 1: return 1
        case 2, 3: return 2
        case 4: return 3
        default: return 0
        }
    }

    private func goTo(_ step: Int) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            currentStep = step
        }
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()

            LogoImage(size: 72)
                .scaleEffect(logoAppeared ? 1.0 : 0.5)
                .opacity(logoAppeared ? 1.0 : 0)

            Text("Azex Speech")
                .font(.title.bold())
                .foregroundStyle(AzexTheme.textPrimary)
                .opacity(logoAppeared ? 1.0 : 0)
                .offset(y: logoAppeared ? 0 : 10)

            Text("Voice input for Crypto & AI professionals")
                .foregroundStyle(AzexTheme.textSecondary)
                .opacity(logoAppeared ? 1.0 : 0)
                .offset(y: logoAppeared ? 0 : 10)

            Spacer().frame(height: 8)

            Button("开始设置") {
                goTo(1)
            }
            .buttonStyle(.borderedProminent)
            .tint(AzexTheme.accent)
            .controlSize(.large)
            .opacity(logoAppeared ? 1.0 : 0)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.2)) {
                logoAppeared = true
            }
        }
    }

    // MARK: - Step 1: Hotkey

    private var hotkeyStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("设置语音快捷键")
                .font(.title2.bold())
                .foregroundStyle(AzexTheme.textPrimary)

            // Simplified keyboard illustration
            KeyboardIllustration()
                .frame(width: 360, height: 100)

            KeyboardShortcuts.Recorder("自定义快捷键:", name: .toggleRecording)
                .padding(.horizontal, 40)

            Text("按一下右侧 Option 键开始说话，再按一下完成识别")
                .font(.callout)
                .foregroundStyle(AzexTheme.textSecondary)

            Spacer().frame(height: 8)

            Button("下一步") {
                goTo(2)
            }
            .buttonStyle(.borderedProminent)
            .tint(AzexTheme.accent)
            .controlSize(.large)

            Spacer()
        }
    }

    // MARK: - Step 2: Domain

    private var domainStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("你主要在哪个领域？")
                .font(.title2.bold())
                .foregroundStyle(AzexTheme.textPrimary)

            HStack(spacing: 16) {
                DomainCard(
                    systemImage: "brain.head.profile",
                    title: "AI",
                    subtitle: "Claude, GPT, LLM, fine-tuning...",
                    badge: nil,
                    isSelected: selectedDomain == "ai"
                ) {
                    selectedDomain = "ai"
                }

                DomainCard(
                    systemImage: "bitcoinsign.circle",
                    title: "Crypto",
                    subtitle: "Solana, DeFi, TVL, staking...",
                    badge: nil,
                    isSelected: selectedDomain == "crypto"
                ) {
                    selectedDomain = "crypto"
                }

                DomainCard(
                    systemImage: "sparkles",
                    title: "Both",
                    subtitle: "AI + Crypto",
                    badge: "推荐",
                    isSelected: selectedDomain == "both"
                ) {
                    selectedDomain = "both"
                }
            }
            .padding(.horizontal, 32)

            Spacer().frame(height: 8)

            Button("下一步") {
                goTo(3)
            }
            .buttonStyle(.borderedProminent)
            .tint(AzexTheme.accent)
            .controlSize(.large)

            Spacer()
        }
    }

    // MARK: - Step 3.5: Calibration

    private var calibrationStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("要现在校准语音识别吗？")
                .font(.title2.bold())
                .foregroundStyle(AzexTheme.textPrimary)

            Text("我们准备了一些领域文本，朗读后可以让识别更准确")
                .font(.callout)
                .foregroundStyle(AzexTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)

            Spacer().frame(height: 12)

            VStack(spacing: 12) {
                Button("现在校准") {
                    // Calibration not yet implemented — skip to complete
                    goTo(4)
                }
                .buttonStyle(.borderedProminent)
                .tint(AzexTheme.accent)
                .controlSize(.large)

                Button("稍后再说") {
                    goTo(4)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AzexTheme.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Step 4: Complete

    private var completeStep: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack(alignment: .bottomTrailing) {
                LogoImage(size: 64)

                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AzexTheme.success)
                    .background(Circle().fill(AzexTheme.bg).frame(width: 20, height: 20))
                    .offset(x: 4, y: 4)
            }

            Text("一切就绪")
                .font(.title.bold())
                .foregroundStyle(AzexTheme.textPrimary)

            Text("按一下右侧 Option 键开始说话")
                .font(.callout)
                .foregroundStyle(AzexTheme.textSecondary)

            Spacer().frame(height: 4)

            // Menu bar guidance
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up")
                        .font(.caption.bold())
                        .foregroundStyle(AzexTheme.accent)
                        .opacity(menuBarArrowVisible ? 1 : 0.3)

                    Text("在右上角菜单栏找到")
                        .font(.callout)
                        .foregroundStyle(AzexTheme.textSecondary)

                    Image(systemName: "waveform")
                        .font(.callout)
                        .foregroundStyle(AzexTheme.textPrimary)

                    Text("图标")
                        .font(.callout)
                        .foregroundStyle(AzexTheme.textSecondary)
                }

                Text("点击图标打开控制面板 · 快捷键随时输入")
                    .font(.caption)
                    .foregroundStyle(AzexTheme.textTertiary)
            }
            .padding(14)
            .background(AzexTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(AzexTheme.border, lineWidth: 1)
            )

            Spacer().frame(height: 8)

            Button("开始使用") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .tint(AzexTheme.accent)
            .controlSize(.large)

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                menuBarArrowVisible = true
            }
        }
    }
}

// MARK: - Domain Card

private struct DomainCard: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let badge: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(AzexTheme.accent)

            Text(title)
                .font(.headline)
                .foregroundStyle(AzexTheme.textPrimary)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AzexTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let badge {
                Text(badge)
                    .font(.caption2)
                    .foregroundStyle(AzexTheme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AzexTheme.accentMuted)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 130)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AzexTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? AzexTheme.accent : AzexTheme.border, lineWidth: isSelected ? 2 : 1)
        )
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AzexTheme.accent)
                    .padding(8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Keyboard Illustration

private struct KeyboardIllustration: View {
    @State private var glowOpacity: Double = 0.4

    // Simplified 3-row keyboard layout
    // Row widths represent relative key sizes
    private let topRow = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
    private let midRow = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
    private let botRow = [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2]
    // Space row: fn, ctrl, opt, cmd, space, cmd, opt(RIGHT), arrows
    // Index 6 is the right Option key

    var body: some View {
        VStack(spacing: 3) {
            keyRow(topRow, highlightIndex: nil)
            keyRow(midRow, highlightIndex: nil)
            keyRow(botRow, highlightIndex: nil)
            spaceRow()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
    }

    private func keyRow(_ widths: [Int], highlightIndex _: Int?) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(widths.enumerated()), id: \.offset) { _, w in
                RoundedRectangle(cornerRadius: 3)
                    .fill(AzexTheme.bgCard)
                    .frame(width: CGFloat(w) * 24, height: 16)
            }
        }
    }

    private func spaceRow() -> some View {
        HStack(spacing: 2) {
            // fn
            smallKey(width: 24)
            // ctrl
            smallKey(width: 24)
            // left opt
            smallKey(width: 24)
            // left cmd
            smallKey(width: 30)
            // space bar
            RoundedRectangle(cornerRadius: 3)
                .fill(AzexTheme.bgCard)
                .frame(width: 120, height: 16)
            // right cmd
            smallKey(width: 30)
            // RIGHT OPTION — highlighted
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(AzexTheme.accent.opacity(0.3))
                    .frame(width: 24, height: 16)

                RoundedRectangle(cornerRadius: 3)
                    .stroke(AzexTheme.accent, lineWidth: 1.5)
                    .frame(width: 24, height: 16)
                    .shadow(color: AzexTheme.accent.opacity(glowOpacity), radius: 6)

                Text("\u{2325}")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(AzexTheme.accent)
            }
            // arrows placeholder
            smallKey(width: 24)
            smallKey(width: 24)
        }
    }

    private func smallKey(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(AzexTheme.bgCard)
            .frame(width: width, height: 16)
    }
}
