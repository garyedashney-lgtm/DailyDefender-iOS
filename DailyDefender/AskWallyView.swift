import SwiftUI

struct AskWallyView: View {
    // keep your existing state/env vars here…

    var body: some View {
        BrandShieldHost { onLeftTap in
            NavigationStack {
                ZStack {
                    AppTheme.navy900.ignoresSafeArea()

                    // === YOUR ASK WALLY CONTENT GOES HERE ===
                    // e.g., chat UI / prompt field / messages, etc.
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
                                Text("Ask Wally")
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

private struct Chip: View {
    let label: String
    let system: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: system)
                .imageScale(.small)
            Text(label)
                .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(AppTheme.textPrimary)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.navy900.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.divider, lineWidth: 1)
        )
    }
}

private struct Bullet: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.top, -2)
            Text(text)
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview { AskWallyView() }
