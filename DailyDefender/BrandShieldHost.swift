import SwiftUI

/// Wrap any screen in this to:
/// - centralize the full-screen brand presentation
/// - get an `onLeftTap` callback you can pass to your header icon
///
/// Usage:
/// BrandShieldHost { onLeftTap in
///     YourScreen()
///         .appHeader(title: "Title", onLeftTap: onLeftTap)
/// }
struct BrandShieldHost<Content: View>: View {
    @State private var showBrand = false
    let content: (@escaping () -> Void) -> Content

    var body: some View {
        ZStack {
            content { showBrand = true }

            if showBrand {
                ShieldSplashView(
                    onRevealStart: { },
                    onFinish: {
                        withAnimation(.easeInOut(duration: 0.20)) {
                            showBrand = false
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
        // ✅ Critical: if this host is being dismissed / navigated away,
        // never let a leftover `showBrand` state flash a splash.
        .onDisappear {
            showBrand = false
        }
    }
}
