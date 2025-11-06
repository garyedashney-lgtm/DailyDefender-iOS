import SwiftUI

struct MainTabScaffoldView: View {
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var session: SessionViewModel

    @State private var currentPage: IosPage = .daily

    // Version labels for footer
    private var versionName: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
    private var versionCode: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
    }
    // ISO week key (matches Android “YYYY-Www” vibe)
    private var weekKey: String {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let y = comps.yearForWeekOfYear ?? 0
        let w = comps.weekOfYear ?? 0
        return "W\(w)-\(y)"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Switch among your 5 top-level pages.
            // These views already include their own NavigationStack/toolbars.
            Group {
                switch currentPage {
                case .daily:
                    DailyView()
                        .environmentObject(store)
                        .accessibilityIdentifier("tab_daily")

                case .weekly:
                    WeeklyView()
                        .environmentObject(store)
                        .accessibilityIdentifier("tab_weekly")

                case .goals:
                    GoalsView()
                        .environmentObject(store)
                        .accessibilityIdentifier("tab_goals")

                case .journal:
                    JournalHomeView()
                        .environmentObject(store)
                        .accessibilityIdentifier("tab_journal")

                case .more:
                    MoreView()
                        .environmentObject(store)
                        .accessibilityIdentifier("tab_more")
                }
            }
            .ignoresSafeArea(.keyboard) // footer stays put when keyboard shows

            // Global footer
            IOSFooterBar(
                currentPage: currentPage,
                onSelectPage: { page in currentPage = page },
                versionName: versionName,
                versionCode: versionCode,
                weekKey: weekKey
            )
        }
        .background(AppTheme.navy900.ignoresSafeArea())
    }
}

