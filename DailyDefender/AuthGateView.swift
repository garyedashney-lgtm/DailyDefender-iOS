import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject var session: SessionViewModel
    @EnvironmentObject var store: HabitStore

    var body: some View {
        Group {
            if (store.profile.isRegistered) && (session.user != nil) {
                MainTabScaffoldView()
                    .environmentObject(store)
                    .environmentObject(session)
            } else {
                RegistrationView {
                    Task {
                        await session.runSeedIfNeeded()
                        await session.refreshEntitlements()
                    }
                }
                .environmentObject(store)
                .environmentObject(session)
            }
        }
    }
}
