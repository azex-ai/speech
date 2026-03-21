import SwiftUI

struct HistoryView: View {
    @ObservedObject private var historyManager = HistoryManager.shared
    @State private var selectedDate: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }()
    @State private var selectedEntries: [HistoryEntry] = []

    private var availableDates: [String] {
        let dates = historyManager.allDates()
        let today = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()
        if dates.contains(today) {
            return dates
        }
        return [today] + dates
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("History")
                .font(.title2.bold())
                .foregroundStyle(AzexTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            // Date picker — horizontal scroll of date pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(availableDates, id: \.self) { dateStr in
                        DatePill(
                            dateString: dateStr,
                            entryCount: entryCount(for: dateStr),
                            isSelected: dateStr == selectedDate
                        )
                        .onTapGesture {
                            selectedDate = dateStr
                            loadEntries(for: dateStr)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            AzexTheme.border
                .frame(height: 1)

            // Entries for selected date
            if selectedEntries.isEmpty {
                VStack {
                    Spacer()
                    Text("No sessions recorded on this date.")
                        .foregroundStyle(AzexTheme.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(selectedEntries) { entry in
                            EntryRow(entry: entry)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(AzexTheme.bg)
        .onAppear {
            loadEntries(for: selectedDate)
        }
    }

    private func loadEntries(for dateStr: String) {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        if let date = f.date(from: dateStr) {
            selectedEntries = historyManager.loadDate(date)
        } else {
            selectedEntries = []
        }
    }

    private func entryCount(for dateStr: String) -> Int {
        if dateStr == selectedDate {
            return selectedEntries.count
        }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateStr) else { return 0 }
        return historyManager.loadDate(date).count
    }
}

// MARK: - Subviews

private struct DatePill: View {
    let dateString: String
    let entryCount: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(dateString)
                .font(isSelected ? .callout.bold() : .callout)
                .foregroundStyle(isSelected ? .white : AzexTheme.textSecondary)
            Text("\(entryCount) sessions")
                .font(.caption2)
                .foregroundStyle(isSelected ? .white.opacity(0.8) : AzexTheme.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isSelected ? AzexTheme.accent : AzexTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct EntryRow: View {
    let entry: HistoryEntry

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: entry.timestamp)
    }

    private var durationSeconds: String {
        String(format: "%.1fs", Double(entry.durationMs) / 1000.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(timeString)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(AzexTheme.accentText)

                Spacer()

                Text(durationSeconds)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AzexTheme.textSecondary)

                Text("\(entry.charCount) chars")
                    .font(.caption2)
                    .foregroundStyle(AzexTheme.textSecondary)
            }

            if entry.original != entry.corrected {
                HStack(alignment: .top, spacing: 6) {
                    Text(entry.original)
                        .font(.callout)
                        .foregroundStyle(AzexTheme.error)
                        .strikethrough(color: AzexTheme.error.opacity(0.6))

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(AzexTheme.textSecondary)

                    Text(entry.corrected)
                        .font(.callout.bold())
                        .foregroundStyle(AzexTheme.textPrimary)
                }
            } else {
                Text(entry.corrected)
                    .font(.callout)
                    .foregroundStyle(AzexTheme.textPrimary)
            }

            if !entry.learned.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(Array(entry.learned.enumerated()), id: \.offset) { _, pair in
                        if pair.count == 2 {
                            Text("\(pair[0]) -> \(pair[1])")
                                .font(.caption2)
                                .foregroundStyle(AzexTheme.success)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
        }
        .azexCard(padding: 10)
    }
}

// MARK: - Simple Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

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
            totalWidth = max(totalWidth, x - spacing)
            totalHeight = y + rowHeight
        }

        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}
