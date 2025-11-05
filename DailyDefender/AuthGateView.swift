import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject var session: SessionViewModel
    @EnvironmentObject var store: HabitStore

    var body: some View {
        Group {
            if session.user != nil {
                // ✅ Signed in → enter the app (Free by default; pro unlocks via Firestore)
                RootView()
                    .environmentObject(store)
            } else {
                RegistrationView(onRegistered: {
                    // no-op: SessionViewModel listener will flip user != nil
                })
                .environmentObject(store)
            }
        }
    }
}
