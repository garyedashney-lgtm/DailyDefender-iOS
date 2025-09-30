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
        content { showBrand = true }
            .fullScreenCover(isPresented: $showBrand) {
                ShieldBrandFullscreen()
            }
    }
}
