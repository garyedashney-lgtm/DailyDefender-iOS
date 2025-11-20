import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var session: SessionViewModel   // 🔹 current user + tier

    // Tabs
    @State private var tab: IosPage = .daily

    // Post-registration brand splash (spinner)
    @State private var showBrandSplash = false

    // Center toast so keyboard can't cover it
    @State private var toastMessage: String?
    @State private var showToast = false

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            // 🔐 Top-level auth gate:
            // If not signed in, show auth flow only.
            if session.user == nil {
                AuthRootView(
                    onAuthenticated: {
                        // When auth completes, default to Daily tab
                        tab = .daily
                    }
                )
                .environmentObject(store)
                .environmentObject(session)
            } else {
                // Signed-in experience: main tabbed app
                Content(tab: $tab)
                    .environmentObject(store)
                    .environmentObject(session)
            }

            // Center toast overlay (independent of keyboard)
            if showToast, let msg = toastMessage {
                CenterToastView(message: msg)
                    .allowsHitTesting(false)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(2)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                            withAnimation { showToast = false }
                            // Clear the one-shot message so it won't retrigger
                            store.lastMailchimpMessage = nil
                        }
                    }
            }
        }
        // 🔔 Mailchimp / registration messages → just show toast
        .onReceive(store.$lastMailchimpMessage.compactMap { $0 }) { msg in
            toastMessage = msg
            withAnimation { showToast = true }
        }
        // Listen for one-time post-registration spinner trigger from HabitStore
        .onReceive(store.$revealBrandAfterRegistration) { flag in
            guard flag else { return }
            showBrandSplash = true
        }
        .fullScreenCover(isPresented: $showBrandSplash, onDismiss: {
            // Reset store flag so it won't loop
            store.revealBrandAfterRegistration = false
        }) {
            ShieldBrandFullscreen()
        }
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
                        PaywallCardView(title: "Pro Feature")
                    }

                case .goals:
                    if session.tier.canAccessWeeklyAndGoals {
                        GoalsView()
                            .environmentObject(store)
                    } else {
                        PaywallCardView(title: "Pro Feature")
                    }

                case .journal:
                    if session.tier.canAccessJournal {
                        JournalHomeView()
                            .environmentObject(store)
                    } else {
                        PaywallCardView(title: "Pro Feature")
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

// MARK: - Simple center toast (keyboard-safe)

private struct CenterToastView: View {
    let message: String
    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .font(.footnote.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.surfaceUI)
                .foregroundStyle(AppTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(radius: 6)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - Placeholders you already had

private struct PlaceholderView: View {
    let title: String
    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()
            Text("\(title) — Coming Soon")
                .foregroundStyle(AppTheme.textSecondary)
                .padding()
        }
    }
}

private struct GoalsPlaceholderView: View {
    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()
            Text("Goals — Coming Soon")
                .foregroundStyle(AppTheme.textSecondary)
                .padding()
        }
    }
}

private struct JournalPlaceholderView: View {
    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()
            Text("Journal — Coming Soon")
                .foregroundStyle(AppTheme.textSecondary)
                .padding()
        }
    }
}

private extension Notification.Name {
    static let reselectTab = Notification.Name("reselectTab")
}
