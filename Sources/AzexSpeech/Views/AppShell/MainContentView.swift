import SwiftUI

struct MainContentView: View {
    @State private var selection: SidebarItem? = .dashboard

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            Group {
                switch selection {
                case .dashboard:
                    DashboardView()
                case .history:
                    HistoryView()
                case .vocabulary:
                    VocabularyView()
                case .feed:
                    FeedView()
                case .calibration:
                    CalibrationView()
                case .training:
                    PronunciationTrainerView()
                case .settings:
                    SettingsMainView()
                case .none:
                    DashboardView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AzexTheme.bg)
        }
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(.dark)
    }
}
