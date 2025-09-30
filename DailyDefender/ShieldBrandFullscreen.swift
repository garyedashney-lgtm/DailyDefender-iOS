import SwiftUI

/// Fullscreen spinning brand shield/splash.
/// Standalone: does not reference RootView/ContentView.
struct ShieldBrandFullscreen: View {
    // Optional callback when the splash finishes
    var onFinish: (() -> Void)? = nil

    // Animation config
    private let spinDuration: Double = 1.6
    private let fadeOutDuration: Double = 0.35

    @Environment(\.dismiss) private var dismiss

    @State private var angle: Angle = .degrees(0)
    @State private var scale: CGFloat = 0.9
    @State private var opacity: Double = 1.0
    @State private var isAnimating: Bool = false

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            // Prefer your square shield; fall back to round app logo; then to system icon
            Group {
                if let shield = UIImage(named: "AppShieldSquare") {
                    Image(uiImage: shield).resizable().scaledToFit()
                } else if let round = UIImage(named: "AppLogoRound") {
                    Image(uiImage: round).resizable().scaledToFit()
                } else {
                    Image(systemName: "shield.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(AppTheme.appGreen)
                }
            }
            .padding(64)
            .rotationEffect(angle)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear(perform: start)
        }
    }

    private func start() {
        guard !isAnimating else { return }
        isAnimating = true

        // Spin & pop
        withAnimation(.easeInOut(duration: spinDuration)) {
            angle = .degrees(360)
            scale = 1.0
        }

        // After spin, fade out and dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration) {
            withAnimation(.easeInOut(duration: fadeOutDuration)) {
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) {
                onFinish?()
                dismiss()
            }
        }
    }
}
