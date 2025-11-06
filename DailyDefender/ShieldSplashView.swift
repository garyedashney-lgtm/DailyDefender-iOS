import SwiftUI

struct ShieldSplashView: View {
    /// Called right when the spin begins (start fading in RootView here)
    var onRevealStart: (() -> Void)? = nil
    /// Called when the splash is completely done (remove splash overlay)
    let onFinish: () -> Void

    @State private var opacity: CGFloat = 0
    @State private var scale: CGFloat = 0.92
    @State private var rotation: Angle = .degrees(0)

    var body: some View {
        ZStack {
            // Darker branded background with subtle gradient glow
            LinearGradient(
                colors: [
                    AppTheme.navy900.darker(by: 0.25),
                    AppTheme.navy900
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Image("AppShieldSquare")
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(maxWidth: 420)
                .opacity(opacity)
                .scaleEffect(scale)
                .rotationEffect(rotation)
                .shadow(color: .black.opacity(0.35), radius: 28, x: 0, y: 16)
        }
        .onAppear {
            // 1) Fade in + subtle pop
            withAnimation(.easeOut(duration: 0.6)) {
                opacity = 1
                scale = 1.0
            }

            // 2) Hold the full shield for ~2.5s
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                // 3) Begin reveal: tell the app to start fading in RootView
                onRevealStart?()

                // 4) Spin 360° + gentle zoom + dissolve over 1.6s
                withAnimation(.easeInOut(duration: 1.6)) {
                    rotation = .degrees(360)
                    scale = 1.2
                    opacity = 0
                }

                // 5) When spin completes, finish (remove splash overlay)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    onFinish()
                }
            }
        }
    }
}

// MARK: - Darken helper for AppTheme colors
private extension Color {
    func darker(by amount: CGFloat) -> Color {
        let uiColor = UIColor(self)
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
        return Color(hue: hue, saturation: sat, brightness: max(bri - amount, 0), opacity: Double(alpha))
    }
}
