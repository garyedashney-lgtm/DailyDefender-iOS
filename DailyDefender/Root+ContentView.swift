import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: HabitStore

    // Tabs
    @State private var tab: IosPage = .daily

    // First-run sheet (registration or profile completion)
    @State private var showOnboardingSheet = false

    // Post-registration brand splash (spinner)
    @State private var showBrandSplash = false

    // Center toast so keyboard can't cover it
    @State private var toastMessage: String?
    @State private var showToast = false

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            // Main content with tabs
            Content(tab: $tab)
                .environmentObject(store)

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
        .onAppear {
            // Show sheet if missing name or not registered
            let p = store.profile
            showOnboardingSheet =
                p.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !p.isRegistered
        }
        .sheet(isPresented: $showOnboardingSheet) {
            // Registration flow (Root listens for toast via store.$lastMailchimpMessage)
            RegistrationView {
                // Just dismiss; DO NOT set the tab here.
                // We will switch to Daily only when Mailchimp success flips isRegistered.
                showOnboardingSheet = false
            }
            .environmentObject(store)
        }
        // Mailchimp message -> show toast AND, if isRegistered is now true, go to Daily.
        .onReceive(store.$lastMailchimpMessage.compactMap { $0 }) { msg in
            let becameRegistered = store.profile.isRegistered  // authoritative success flag

            if showOnboardingSheet {
                // Dismiss the sheet first, then show toast and switch tab if registered
                showOnboardingSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    if becameRegistered { tab = .daily }
                    toastMessage = msg
                    withAnimation { showToast = true }
                }
            } else {
                if becameRegistered { tab = .daily }
                toastMessage = msg
                withAnimation { showToast = true }
            }
        }
        // Listen for one-time post-registration spinner trigger from HabitStore
        .onReceive(store.$revealBrandAfterRegistration) { flag in
            guard flag else { return }
            // Present spinner, then reset the flag when it dismisses
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

// MARK: - Content wrapper that switches tabs
private struct Content: View {
    @EnvironmentObject var store: HabitStore
    @Binding var tab: IosPage

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            Group {
                switch tab {
                case .daily:   DailyView()
                case .weekly:  WeeklyView()
                case .monthly: PlaceholderView(title: "Monthly")
                case .seasons: PlaceholderView(title: "Seasons")
                case .more:    InfoView()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            IOSFooterBar(
                currentPage: tab,
                onSelectPage: { tab = $0 },
                versionName: Bundle.main.appVersion,
                versionCode: Bundle.main.appBuild,
                weekKey: currentWeekKey()
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
