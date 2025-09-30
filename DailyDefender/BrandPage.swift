import SwiftUI

/// Static brand info screen with a back button.
/// Shows the brand shield, a short tagline, and uses your dark theme.
/// This *does not* trigger the spinning fullscreen splash.
struct BrandPage: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Brand Shield (static)
                    if let img = UIImage(named: "AppShieldSquare") {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(AppTheme.divider, lineWidth: 1)
                            )
                            .padding(.top, 24)
                    } else {
                        // Fallback if asset missing
                        Image(systemName: "shield.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 160)
                            .padding(.top, 24)
                            .foregroundStyle(AppTheme.appGreen)
                    }

                    // Title / copy (tweak to your copy)
                    VStack(spacing: 8) {
                        Text("Daily Defender")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)

                        Text("Power • Piety • People • Production")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 24)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Brand")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.navy900, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}
