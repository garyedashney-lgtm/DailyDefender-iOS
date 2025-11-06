import SwiftUI

struct MoreView: View {
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var session: SessionViewModel   // ← 1) add

    // Header actions
    @State private var showMoreShield = false
    @State private var goProfileEdit = false           // ← 2) add

    private let moreShieldAsset = "AppShieldSquare"

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navy900.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        MoreCard(
                            title: "How To Use App",
                            emoji: "📖",
                            destination: AnyView(InfoView().environmentObject(store))
                        )

                        MoreCard(
                            title: "Resources",
                            emoji: "📚",
                            destination: AnyView(ResourcesView().environmentObject(store))
                        )

                        Spacer(minLength: 56) // clear the global footer
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }

            // 🔗 Hidden push to ProfileEdit keeps footer visible
            NavigationLink("", isActive: $goProfileEdit) {
                ProfileEditView()
                    .environmentObject(store)
                    .environmentObject(session)
            }
            .hidden()

            // === Standardized toolbar (same as Daily/Weekly/Goals) ===
            .toolbar {
                // LEFT — Shield icon → FULL SCREEN cover to ShieldPage
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showMoreShield = true }) {
                        (UIImage(named: moreShieldAsset) != nil
                         ? Image(moreShieldAsset).resizable().scaledToFit()
                         : Image("AppShieldSquare").resizable().scaledToFit()
                        )
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.textSecondary.opacity(0.4), lineWidth: 1))
                        .padding(4)
                        .offset(y: -2) // optical vertical centering
                    }
                    .accessibilityLabel("Open page shield")
                }

                // CENTER — Title + subtitle
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Text("⋯")
                                .font(.system(size: 18, weight: .semibold))
                            Text("More")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        Text("Settings, help, and resources")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.bottom, 10) // space at bottom of header itself
                }

                // RIGHT — Profile avatar → PUSH (not sheet)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Group {
                        if let path = store.profile.photoPath,
                           let ui = UIImage(contentsOfFile: path) {
                            Image(uiImage: ui).resizable().scaledToFill()
                        } else if UIImage(named: "ATMPic") != nil {
                            Image("ATMPic").resizable().scaledToFill()
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, AppTheme.appGreen)
                        }
                    }
                    .frame(width: 32, height: 32)                    // standardized size
                    .clipShape(RoundedRectangle(cornerRadius: 8))    // standardized radius
                    .offset(y: -2)                                    // optical center
                    .onTapGesture { goProfileEdit = true }            // ← 3) push
                    .accessibilityLabel("Profile")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.navy900, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 48) }

            // Shield full-screen (uses AppShieldSquare; falls back if missing)
            .fullScreenCover(isPresented: $showMoreShield) {
                ShieldPage(
                    imageName: (UIImage(named: moreShieldAsset) != nil ? moreShieldAsset : "AppShieldSquare")
                )
            }
        }
    }
}

// MARK: - Card
private struct MoreCard: View {
    let title: String
    let emoji: String
    let destination: AnyView

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.appGreen.opacity(0.16))
                        .frame(width: 40, height: 40)
                    Text(emoji)
                        .font(.system(size: 20))
                }

                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.surfaceUI)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
