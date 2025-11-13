import SwiftUI

struct MainTabScaffoldView: View {
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var session: SessionViewModel

    @State private var currentPage: IosPage = .daily

    private var versionName: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
    private var versionCode: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
    }
    private var weekKey: String {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return "W\(comps.weekOfYear ?? 0)-\(comps.yearForWeekOfYear ?? 0)"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch currentPage {

                case .daily:
                    DailyView()
                        .environmentObject(store)

                case .weekly:
                    if session.tier.canAccessWeeklyAndGoals {
                        WeeklyView().environmentObject(store)
                    } else {
                        PaywallCardView(title: "Pro Feature")
                    }

                case .goals:
                    if session.tier.canAccessWeeklyAndGoals {
                        GoalsView().environmentObject(store)
                    } else {
                        PaywallCardView(title: "Pro Feature")
                    }

                case .journal:
                    if session.tier.canAccessJournal {
                        JournalHomeView().environmentObject(store)
                    } else {
                        PaywallCardView(title: "Pro Feature")
                    }

                case .more:
                    MoreView().environmentObject(store)
                }
            }
            .ignoresSafeArea(.keyboard)

            IOSFooterBar(
                currentPage: currentPage,
                onSelectPage: { currentPage = $0 },
                versionName: versionName,
                versionCode: versionCode,
                weekKey: weekKey
            )
        }
        .background(AppTheme.navy900.ignoresSafeArea())
    }
}

extension UserTier {
    var canAccessWeeklyAndGoals: Bool {
        switch self {
        case .free: return false
        case .amateur, .pro: return true
        }
    }

    var canAccessJournal: Bool {
        self == .pro
    }
}
