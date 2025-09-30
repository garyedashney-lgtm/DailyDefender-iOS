import SwiftUI

struct ShieldShowcaseView: View {
    /// Name of the asset in your xcassets (e.g., "four_ps" or "AppShieldSquare")
    let imageName: String
    var title: String = "The 4 Ps" // tweak per caller

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navy900.ignoresSafeArea()

                GeometryReader { geo in
                    VStack {
                        Spacer(minLength: 0)
                        if let ui = UIImage(named: imageName) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFit()               // full width, maintains aspect
                                .frame(maxWidth: geo.size.width * 0.92)
                                .shadow(radius: 10)
                                .accessibilityLabel(title)
                        } else {
                            // Fallback if asset missing
                            Image(systemName: "shield.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: geo.size.width * 0.5)
                                .foregroundStyle(AppTheme.appGreen)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(AppTheme.navy900, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
