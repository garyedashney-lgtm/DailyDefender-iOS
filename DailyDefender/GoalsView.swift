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

                        // ===== Page Title & Subtitle (centered) =====
                        VStack(spacing: 4) {
                            Text("DEFENDER DESTINY")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)

                            Text("Who Am I? Who Shall I Be?")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.top, 6)
                        .padding(.bottom, 12) // slightly tighter than before

                        // ===== Who Am I? =====
                        GoalsSectionHeader(title: "Who Am I?")

                        NavigationLink {
                            CurrentStateView()
                                .environmentObject(store)
                        } label: {
                            GoalsCardRowSimple(
                                title: "Current State",
                                subtitle: "The full truth of where you are at now.",
                                emoji: "🧭"
                            )
                        }
                        .buttonStyle(.plain)

                        // ↓ Reduced gap before next section title
                        Spacer().frame(height: 0)

                        // ===== Who Shall I Be? =====
                        GoalsSectionHeader(title: "Who Shall I Be?")

                        // Destiny Vision
                        NavigationLink {
                            DestinyVisionView()
                                
                                .environmentObject(store) // keeps it consistent with CurrentStateView
                        } label: {
                            GoalsCardRowSimple(
                                title: "Destiny Vision",
                                subtitle: "Define your ‘I am / I will’ for each quadrant.",
                                emoji: "🧭"    // optional: change to "🚀" if you want Android parity
                            )
                        }
                        .buttonStyle(.plain)

                        // Yearly Goals
                        NavigationLink {
                            YearlyGoalsView().environmentObject(store)
                        } label: {
                            GoalsCardRowSimple(
                                title: "Yearly Goals",
                                subtitle: "Set your North Star and anchor the year.",
                                emoji: "🗓️"
                            )
                        }
                        .buttonStyle(.plain)

                        // Seasonal Goals
                        NavigationLink {
                            SeasonsGoalsView().environmentObject(store)
                        } label: {
                            GoalsCardRowSimple(
                                title: "Seasonal Goals",
                                subtitle: "Break yearly focus down into seasons.",
                                emoji: seasonEmoji
                            )
                        }
                        .buttonStyle(.plain)

                        // Monthly Goals
                        NavigationLink {
                            MonthlyGoalsView().environmentObject(store)
                        } label: {
                            GoalsCardRowSimple(
                                title: "Monthly Goals",
                                subtitle: "Plan this month’s focus and milestones.",
                                emoji: "📅"
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
                        .offset(y: -2)
                    }
                    .accessibilityLabel("Open page shield")
                }

                // CENTER — Title
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Text("🎯")
                            .font(.system(size: 18, weight: .regular))
                        Text("Goals")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(.bottom, 10)
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
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .offset(y: -2)
                    .onTapGesture { showProfileEdit = true }
                    .accessibilityLabel("Profile")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.navy900, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 48) }

            // Shield full-screen
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

// MARK: - Section Header
private struct GoalsSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card (accent + accessibility tweaks)
private struct GoalsCardRowSimple: View {
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
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.8))
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

// MARK: - Placeholder
private struct ComingSoonView: View {
    let title: String
    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("This screen will be linked up soon.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
