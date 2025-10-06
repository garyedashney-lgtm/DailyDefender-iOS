import SwiftUI

struct GoalsView: View {
    @EnvironmentObject var store: HabitStore

    // Header actions
    @State private var showGoalsShield = false
    @State private var showProfileEdit = false

    // Meteorological season → emoji
    private var seasonEmoji: String {
        let m = Calendar.current.component(.month, from: Date())
        switch m {
        case 12, 1, 2:   return "❄️" // Winter
        case 3, 4, 5:    return "🌸" // Spring
        case 6, 7, 8:    return "☀️" // Summer
        default:         return "🍂" // Fall (9,10,11)
        }
    }

    // Shield asset for this page
    private let goalsShieldAsset = "identityncrisis"

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navy900.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {

                        // Monthly Goals
                        NavigationLink {
                            MonthlyGoalsPlaceholder().environmentObject(store)
                        } label: {
                            GoalsCardRow(
                                title: "Monthly Goals",
                                subtitle: "Plan this month’s focus, milestones, and habits.",
                                emoji: "📅"
                            )
                        }
                        .buttonStyle(.plain)

                        // Seasonal Goals
                        NavigationLink {
                            SeasonsGoalsPlaceholder().environmentObject(store)
                        } label: {
                            GoalsCardRow(
                                title: "Seasonal Goals",
                                subtitle: "Zoom out by season for bigger arcs and outcomes.",
                                emoji: seasonEmoji
                            )
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 56) // keep clear of global footer
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }

            // === Standardized toolbar (matches Daily/Weekly) ===
            .toolbar {
                // LEFT — Shield icon → FULL SCREEN cover to ShieldPage
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showGoalsShield = true }) {
                        (UIImage(named: goalsShieldAsset) != nil
                         ? Image(goalsShieldAsset).resizable().scaledToFit()
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
                            Text("🎯")
                                .font(.system(size: 18, weight: .regular))
                            Text("Goals")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        Text("Monthly & seasonal outcomes")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.bottom, 10) // space at bottom of header itself
                }

                // RIGHT — Profile avatar → ProfileEditView sheet
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
                    .onTapGesture { showProfileEdit = true }
                    .accessibilityLabel("Profile")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.navy900, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 48) }

            // Shield full-screen (uses identityncrisis; falls back if missing)
            .fullScreenCover(isPresented: $showGoalsShield) {
                ShieldPage(
                    imageName: (UIImage(named: goalsShieldAsset) != nil ? goalsShieldAsset : "AppShieldSquare")
                )
            }

            // Profile sheet
            .sheet(isPresented: $showProfileEdit) {
                ProfileEditView().environmentObject(store)
            }
        }
    }
}

// MARK: - Card (no button; wrap with NavigationLink)
private struct GoalsCardRow: View {
    let title: String
    let subtitle: String
    let emoji: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.appGreen.opacity(0.16))
                    .frame(width: 40, height: 40)
                Text(emoji)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
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
}

// MARK: - Temporary placeholders (replace with your real views)
private struct MonthlyGoalsPlaceholder: View {
    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()
            Text("Monthly Goals — Coming Soon")
                .foregroundStyle(AppTheme.textSecondary)
                .padding()
        }
        .navigationTitle("Monthly Goals")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SeasonsGoalsPlaceholder: View {
    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()
            Text("Seasonal Goals — Coming Soon")
                .foregroundStyle(AppTheme.textSecondary)
                .padding()
        }
        .navigationTitle("Seasonal Goals")
        .navigationBarTitleDisplayMode(.inline)
    }
}
