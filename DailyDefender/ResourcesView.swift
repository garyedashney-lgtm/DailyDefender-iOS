import SwiftUI

struct ResourcesView: View {
    // keep your existing state/env vars here…

    var body: some View {
        BrandShieldHost { onLeftTap in
            NavigationStack {
                ZStack {
                    AppTheme.navy900.ignoresSafeArea()

                    // === YOUR RESOURCES CONTENT GOES HERE ===
                    // e.g., List of links/cards/videos, etc.
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        ZStack {
                            HStack {
                                Image("AppShieldSquare")
                                    .resizable()
                                    .interpolation(.high)
                                    .antialiased(true)
                                    .scaledToFit()
                                    .frame(width: 36, height: 36)
                                    .padding(4)
                                    .contentShape(Rectangle())
                                    .onTapGesture { onLeftTap() }
                                    .accessibilityLabel("Open Brand Shield")

                                Spacer()

                                Image(systemName: "person.crop.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, AppTheme.appGreen)
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 9))
                            }

                            VStack(spacing: 2) {
                                Text("Resources")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(AppTheme.navy900, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            }
        }
    }
}

#Preview { ResourcesView() }
