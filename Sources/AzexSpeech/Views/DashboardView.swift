import SwiftUI

struct DashboardView: View {
    @ObservedObject private var statsManager = StatsManager.shared
    @ObservedObject private var historyManager = HistoryManager.shared
    @State private var wordsLearnedCount: Int = 0
    @State private var showClearConfirm = false

    private var isFirstTime: Bool {
        statsManager.stats.totalSessions == 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Stats row — pinned, always visible
            HStack(spacing: 16) {
                StatCard(
                    title: "累计输出",
                    value: statsManager.stats.totalCharacters.formatted(),
                    unit: "字",
                    icon: "character.cursor.ibeam"
                )
                StatCard(
                    title: "节省时间",
                    value: formattedTimeSaved(statsManager.stats.timeSavedMinutes),
                    unit: nil,
                    icon: "clock"
                )
                StatCard(
                    title: "已学词汇",
                    value: "\(wordsLearnedCount)",
                    unit: "个",
                    icon: "book.closed"
                )
                StatCard(
                    title: "今日会话",
                    value: "\(statsManager.todaySessionCount)",
                    unit: "次",
                    icon: "calendar"
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            AzexTheme.border.frame(height: 1).padding(.horizontal, 20)

            // Scrollable content below
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if historyManager.entries.isEmpty {
                        if isFirstTime {
                            // First-time guidance
                            VStack(spacing: 16) {
                                Image(systemName: "waveform.and.mic")
                                    .font(.system(size: 40))
                                    .foregroundStyle(AzexTheme.textTertiary)

                                Text("开始使用语音输入")
                                    .font(.headline)
                                    .foregroundStyle(AzexTheme.textPrimary)

                                Text("按下右侧 Option 键开始录音\n再按一下完成识别并自动粘贴")
                                    .font(.callout)
                                    .foregroundStyle(AzexTheme.textSecondary)
                                    .multilineTextAlignment(.center)

                                HStack(spacing: 24) {
                                    guideStep(number: "1", text: "按右 Option")
                                    guideStep(number: "2", text: "说话")
                                    guideStep(number: "3", text: "再按一下")
                                    guideStep(number: "4", text: "自动粘贴")
                                }
                                .padding(.top, 8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            // Post-clear empty state
                            HStack {
                                Spacer()
                                Text("今日暂无会话")
                                    .font(.callout)
                                    .foregroundStyle(AzexTheme.textTertiary)
                                Spacer()
                            }
                            .padding(.vertical, 32)
                        }
                    } else {
                        // History header
                        HStack {
                            Text("最近会话")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AzexTheme.textSecondary)
                            Spacer()
                            Button("清除全部") {
                                showClearConfirm = true
                            }
                            .font(.caption)
                            .foregroundStyle(AzexTheme.textTertiary)
                            .buttonStyle(.plain)
                            .confirmationDialog(
                                "确定清除今日所有会话记录？",
                                isPresented: $showClearConfirm,
                                titleVisibility: .visible
                            ) {
                                Button("清除全部", role: .destructive) {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        historyManager.clearToday()
                                    }
                                }
                                Button("取消", role: .cancel) {}
                            }
                        }

                        // History rows
                        VStack(spacing: 6) {
                            ForEach(historyManager.entries) { entry in
                                DashboardHistoryRow(entry: entry, onDelete: {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        historyManager.deleteEntry(id: entry.id)
                                    }
                                })
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(AzexTheme.bg)
        .task {
            let mgr = VocabManager()
            mgr.loadAll()
            wordsLearnedCount = mgr.personalVocab.corrections.count
        }
    }

    private func formattedTimeSaved(_ minutes: Double) -> String {
        if minutes >= 60 {
            return String(format: "%.1f 小时", minutes / 60.0)
        } else if minutes >= 1 {
            return String(format: "%.0f 分钟", minutes)
        } else {
            return "0 分钟"
        }
    }

    private func guideStep(number: String, text: String) -> some View {
        VStack(spacing: 6) {
            Text(number)
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(AzexTheme.accent)
                .clipShape(Circle())

            Text(text)
                .font(.caption)
                .foregroundStyle(AzexTheme.textSecondary)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let unit: String?
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(AzexTheme.accent)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(AzexTheme.textPrimary)
                if let unit {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(AzexTheme.textTertiary)
                }
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(AzexTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .azexCard(padding: 12)
    }
}

// MARK: - Dashboard History Row

struct DashboardHistoryRow: View {
    let entry: HistoryEntry
    let onDelete: () -> Void
    @State private var isHovering = false
    @State private var copied = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(Self.timeFormatter.string(from: entry.timestamp))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(AzexTheme.accentText)
                .frame(minWidth: 40, alignment: .leading)

            Text(entry.corrected)
                .font(.callout)
                .foregroundStyle(AzexTheme.textPrimary)
                .lineLimit(2)
                .truncationMode(.tail)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Action buttons — always in layout, opacity-controlled (no layout shift)
            HStack(spacing: 4) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.corrected, forType: .string)
                    withAnimation(.easeInOut(duration: 0.2)) { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { copied = false }
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(copied ? AzexTheme.success : AzexTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help(copied ? "已复制" : "复制")

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(AzexTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("删除")
            }
            .opacity(isHovering ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovering ? AzexTheme.bgCardHover : AzexTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(AzexTheme.borderSubtle, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.12), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
