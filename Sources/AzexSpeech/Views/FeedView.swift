import SwiftUI

struct FeedView: View {
    @ObservedObject private var feedManager = FeedManager.shared
    @State private var searchText = ""
    @State private var expandedID: String?
    @State private var disabledHotwords: Set<String> = []

    private var filteredCaptures: [FeedCapture] {
        if searchText.isEmpty {
            return feedManager.captures
        }
        let query = searchText.lowercased()
        return feedManager.captures.filter { capture in
            capture.sourceApp.lowercased().contains(query)
                || capture.text.lowercased().contains(query)
                || capture.hotwords.contains { $0.lowercased().contains(query) }
        }
    }

    private var totalHotwords: Int {
        var unique = Set<String>()
        for capture in feedManager.captures {
            for word in capture.hotwords {
                unique.insert(word)
            }
        }
        return unique.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Feed")
                    .font(.title2.bold())
                    .foregroundStyle(AzexTheme.textPrimary)
                Spacer()
                Button {
                    feedManager.captureCurrentWindow()
                } label: {
                    Label("Capture", systemImage: "camera.viewfinder")
                        .font(.callout)
                }
                .buttonStyle(.borderedProminent)
                .tint(AzexTheme.accent)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AzexTheme.textSecondary)
                TextField("Search captures...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AzexTheme.textPrimary)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AzexTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(AzexTheme.bgInput)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(AzexTheme.border, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // List
            if filteredCaptures.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title)
                        .foregroundStyle(AzexTheme.textTertiary)
                    Text(feedManager.captures.isEmpty
                        ? "还没有语料\n点击 Capture 抓取当前窗口文本"
                        : "没有匹配 \"\(searchText)\" 的结果")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AzexTheme.textSecondary)
                        .font(.callout)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredCaptures) { capture in
                            CaptureRow(
                                capture: capture,
                                isExpanded: expandedID == capture.id,
                                disabledHotwords: $disabledHotwords,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedID = expandedID == capture.id ? nil : capture.id
                                    }
                                },
                                onDelete: {
                                    withAnimation {
                                        feedManager.deleteCapture(id: capture.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            }

            // Footer
            HStack {
                Text("\(feedManager.captures.count) captures, \(totalHotwords) hotwords")
                    .font(.caption2)
                    .foregroundStyle(AzexTheme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(AzexTheme.bg)
    }
}

// MARK: - Capture Row

private struct CaptureRow: View {
    let capture: FeedCapture
    let isExpanded: Bool
    @Binding var disabledHotwords: Set<String>
    let onTap: () -> Void
    let onDelete: () -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(capture.sourceApp)
                        .font(.headline)
                        .foregroundStyle(AzexTheme.textPrimary)
                    Text(Self.timeFormatter.string(from: capture.timestamp))
                        .font(.caption2)
                        .foregroundStyle(AzexTheme.textTertiary)
                }
                Spacer()
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(AzexTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            // Text preview or full
            Text(capture.text)
                .font(.caption)
                .foregroundStyle(AzexTheme.textSecondary)
                .lineLimit(isExpanded ? nil : 2)

            // Hotword tags
            if !capture.hotwords.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(capture.hotwords, id: \.self) { word in
                        HotwordTag(
                            word: word,
                            isEnabled: !disabledHotwords.contains(word),
                            onToggle: {
                                if disabledHotwords.contains(word) {
                                    disabledHotwords.remove(word)
                                } else {
                                    disabledHotwords.insert(word)
                                }
                            }
                        )
                    }
                }
            }
        }
        .azexCard(padding: 12)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Hotword Tag

private struct HotwordTag: View {
    let word: String
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Text(word)
            .font(.caption2.weight(.medium))
            .foregroundStyle(isEnabled ? AzexTheme.accent : AzexTheme.textTertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isEnabled ? AzexTheme.accentMuted : AzexTheme.bgCard)
            .clipShape(Capsule())
            .onTapGesture { onToggle() }
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return ArrangeResult(
            positions: positions,
            size: CGSize(width: maxWidth, height: totalHeight)
        )
    }

    private struct ArrangeResult {
        var positions: [CGPoint]
        var size: CGSize
    }
}
