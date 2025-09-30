import SwiftUI

struct WeeklyView: View {
    // keep your existing state/env vars here…

    var body: some View {
        BrandShieldHost { onLeftTap in
            NavigationStack {
                ZStack {
                    AppTheme.navy900.ignoresSafeArea()

                    // === YOUR WEEKLY CONTENT GOES HERE ===
                    // Example:
                    // List { …weekly sections/items… }
                    // .listStyle(.plain)
                    // .scrollContentBackground(.hidden)
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        ZStack {
                            // LEFT / RIGHT
                            HStack {
                                // LEFT: tappable square shield
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

                                // RIGHT: avatar (placeholder)
                                Image(systemName: "person.crop.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, AppTheme.appGreen)
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 9))
                            }

                            // CENTER: title
                            VStack(spacing: 2) {
                                Text("Weekly")
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

#Preview { WeeklyView() }
