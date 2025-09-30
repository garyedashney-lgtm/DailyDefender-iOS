import SwiftUI

@main
struct DailyDefenderApp: App {
    @StateObject private var store = HabitStore()
    @State private var showSplash = true
    @State private var rootOpacity: Double = 0   // Root starts hidden

    init() {
        // ==== NAV BAR: dark background + white titles
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(red: 13/255.0, green: 27/255.0, blue: 42/255.0, alpha: 1.0) // navy900
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = .white

        // ==== TAB BAR: dark background + light gray unselected
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(red: 27/255.0, green: 38/255.0, blue: 59/255.0, alpha: 1.0) // surface
        tab.shadowColor = UIColor.white.withAlphaComponent(0.12)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().unselectedItemTintColor = UIColor(white: 1.0, alpha: 0.6)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Solid backdrop so there’s no flash between splash/root
                AppTheme.navy900.ignoresSafeArea()

                // Root is always underneath and fades in during the shield spin
                RootView()
                    .environmentObject(store)          // ✅ single shared store
                    .tint(AppTheme.appGreen)
                    .opacity(rootOpacity)
                    .animation(.easeIn(duration: 1.6), value: rootOpacity) // match spin duration

                if showSplash {
                    ShieldSplashView(
                        onRevealStart: {
                            // start fading in RootView right as the spin begins
                            rootOpacity = 1
                        },
                        onFinish: {
                            // remove splash overlay after spin completes
                            withAnimation(.easeInOut(duration: 0.35)) {
                                showSplash = false
                            }
                        }
                    )
                    .transition(.opacity)
                }
            }
            // Optional UX: hide status bar while splash is up
            .statusBar(hidden: showSplash)
            .preferredColorScheme(.dark)
        }
    }
}
