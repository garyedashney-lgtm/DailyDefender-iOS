import SwiftUI
import Combine

struct RootView: View {
    @Binding var isAppSplashVisible: Bool
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var session: SessionViewModel

    // Tabs
    @State private var tab: IosPage = .daily

    // ✅ Post-registration splash using SAME ShieldSplashView behavior
    @State private var showPostRegistrationSplash = false

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            // 🔐 Top-level auth gate
            if session.user == nil {
                AuthRootView(
                    onAuthenticated: {
                        tab = .daily
                    }
                )
                .environmentObject(store)
                .environmentObject(session)
            } else {
                Content(tab: $tab)
                    .environmentObject(store)
                    .environmentObject(session)
            }

            // ✅ Post-registration splash overlay (matches app launch splash)
            if showPostRegistrationSplash {
                ShieldSplashView(
                    onRevealStart: {
                        // no-op here; RootView is already visible
                    },
                    onFinish: {
                        withAnimation(.easeInOut(duration: 0.20)) {
                            showPostRegistrationSplash = false
                            isAppSplashVisible = false   // ✅ now alerts can present
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }

        // ✅ One-shot trigger (cannot "replay" on view updates)
        .onReceive(store.brandSplashTrigger) { _ in
            // Block alerts while this splash runs
            isAppSplashVisible = true
            showPostRegistrationSplash = true
        }

        // 🎁 Trial start modal
        .alert(
            "Your 30-day Pro Trial has started",
            isPresented: Binding(
                get: { canPresentAlerts && session.shouldShowTrialStartModal },
                set: { session.shouldShowTrialStartModal = $0 }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            let endLine: String = {
                if let endsAt = session.trialEndsAt {
                    return "Your trial ends on \(endsAt.dateValue().formatted(date: .abbreviated, time: .omitted))."
                } else {
                    return "Enjoy Pro features for the next 30 days."
                }
            }()

            Text(
                """
                \(endLine)

                After it ends, you will revert to Free status and Weekly, Goals, and Journal data and entries will not be accessible unless you upgrade.

                To keep copies of this data prior to reverting to Free status, use the Share button available on these screens to send the entries to your own email for later access.
                """
            )
        }

        // ⚠️ Trial warnings (7/3/1 days remaining)
        .alert(
            trialWarningTitle,
            isPresented: Binding(
                get: { canPresentAlerts && session.shouldShowTrialWarning },
                set: { session.shouldShowTrialWarning = $0 }
            )
        ) {
            Button("OK", role: .cancel) {
                session.shouldShowTrialWarning = false
            }
        } message: {
            Text(trialWarningMessage)
        }
    }

    private var canPresentAlerts: Bool {
        !isAppSplashVisible && !showPostRegistrationSplash
    }

    private var trialWarningTitle: String {
        let d = session.trialWarningDaysRemaining
        if let d {
            return d == 1 ? "Pro Trial ends tomorrow" : "Pro Trial ends in \(d) days"
        }
        return "Pro Trial ending soon"
    }

    private var trialWarningMessage: String {
        let endDateText: String = {
            if let endsAt = session.trialEndsAt {
                return endsAt.dateValue().formatted(date: .abbreviated, time: .omitted)
            }
            return "soon"
        }()

        return """
        Your Pro trial ends on \(endDateText).

        After it ends, you will revert to Free status and Weekly, Goals, and Journal data and entries will not be accessible unless you upgrade.

        To keep copies of this data prior to reverting to Free status, use the Share button available on these screens to send the entries to your own email for later access.

        Your data is not deleted unless you delete the app off your phone. It remains stored on your device even in Free status and will be available again if you upgrade later.
        """
    }
}

// MARK: - Content wrapper that switches tabs (now gated by tier)

private struct Content: View {
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var session: SessionViewModel
    @Binding var tab: IosPage

    private var versionName: String {
        Bundle.main.appVersion
    }

    private var versionCode: String {
        Bundle.main.appBuild
    }

    private var weekKey: String {
        currentWeekKey()
    }

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            Group {
                switch tab {
                case .daily:
                    DailyView()
                        .environmentObject(store)

                case .weekly:
                    if session.tier.canAccessWeeklyAndGoals {
                        WeeklyView()
                            .environmentObject(store)
                    } else {
                        PaywallCardView(title: "Requires Standard Subscription")
                    }

                case .goals:
                    if session.tier.canAccessWeeklyAndGoals {
                        GoalsView()
                            .environmentObject(store)
                    } else {
                        PaywallCardView(title: "Requires Standard Subscription")
                    }

                case .journal:
                    if session.tier.canAccessJournal {
                        JournalHomeView()
                            .environmentObject(store)
                    } else {
                        PaywallCardView(title: "Requires Pro Subscription")
                    }

                case .more:
                    MoreView()
                        .environmentObject(store)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            IOSFooterBar(
                currentPage: tab,
                onSelectPage: { tab = $0 },
                versionName: versionName,
                versionCode: versionCode,
                weekKey: weekKey
            )
        }
    }
}

private extension Notification.Name {
    static let reselectTab = Notification.Name("reselectTab")
}
