import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case history = "History"
    case vocabulary = "Vocabulary"
    case feed = "Feed"
    case calibration = "Calibration"
    case wordTrainer = "Word Trainer"
    case training = "Training"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "chart.bar"
        case .history: return "clock.arrow.circlepath"
        case .vocabulary: return "book"
        case .feed: return "text.badge.plus"
        case .calibration: return "waveform.badge.mic"
        case .wordTrainer: return "character.textbox"
        case .training: return "mouth"
        case .settings: return "gear"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo header
            HStack(spacing: 8) {
                LogoImage(size: 28)

                Text("Azex Speech")
                    .font(.headline)
                    .foregroundStyle(AzexTheme.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            AzexTheme.border
                .frame(height: 1)

            // Navigation items — custom styled
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(SidebarItem.allCases) { item in
                        sidebarRow(item)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }

            Spacer(minLength: 0)
        }
        .background(AzexTheme.bgSidebar)
        .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
    }

    private func sidebarRow(_ item: SidebarItem) -> some View {
        let isSelected = selection == item
        return Button {
            selection = item
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.icon)
                    .font(.body)
                    .foregroundStyle(isSelected ? AzexTheme.accent : AzexTheme.textSecondary)
                    .frame(width: 20)

                Text(item.rawValue)
                    .font(.body)
                    .foregroundStyle(isSelected ? AzexTheme.textPrimary : AzexTheme.textSecondary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? AzexTheme.accent.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
