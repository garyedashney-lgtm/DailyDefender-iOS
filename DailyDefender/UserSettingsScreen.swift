import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Full-screen User Settings page shown from More → "User Settings"
/// Shows three cards:
///  1) Celebration Settings  (collapsible)
///  2) Update Profile
///  3) Manage Subscription
struct UserSettingsScreen: View {
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    /// Canonical tier string ("free", "amateur", "pro") passed from MoreView
    let currentTier: String

    /// Whether this user already has a Stripe subscription (as passed from MoreView).
    let hasStripeSubscription: Bool

    // Celebration section expansion + toggles
    @State private var celebrationsExpanded = false
    @State private var confettiOn = CelebrationSettings.isConfettiEnabled
    @State private var audioOn    = CelebrationSettings.isAudioEnabled
    @State private var videoOn    = CelebrationSettings.isVideoEnabled

    // Profile edit sheet
    @State private var showProfileEdit = false

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {

                    // MARK: Celebration Settings (collapsible)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(AppTheme.navy900.opacity(0.35))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(AppTheme.appGreen)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Celebration Settings")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Confetti, audio, and victory video.")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }

                            Spacer()

                            Image(systemName: celebrationsExpanded ? "chevron.up" : "chevron.down")
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                celebrationsExpanded.toggle()
                            }
                        }

                        if celebrationsExpanded {
                            VStack(spacing: 10) {
                                settingsRow(
                                    title: "Confetti at 2-of-4",
                                    subtitle: "Show confetti when you hit 2 pillars.",
                                    isOn: $confettiOn
                                ) { newValue in
                                    CelebrationSettings.isConfettiEnabled = newValue
                                }

                                settingsRow(
                                    title: "“You are an amazing guy” audio",
                                    subtitle: "Play the audio when you hit 2 pillars.",
                                    isOn: $audioOn
                                ) { newValue in
                                    CelebrationSettings.isAudioEnabled = newValue
                                }

                                settingsRow(
                                    title: "Victory video at 4-of-4",
                                    subtitle: "Show the video when you hit all 4 pillars.",
                                    isOn: $videoOn
                                ) { newValue in
                                    CelebrationSettings.isVideoEnabled = newValue
                                }
                            }
                            .padding(.top, 6)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.surfaceUI)
                            .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                    )

                    // MARK: Update Profile card
                    Button(action: { showProfileEdit = true }) {
                        HStack(spacing: 12) {
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
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Update Profile")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Change your name, email, and photo.")
                                    .font(.caption)
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
                    .buttonStyle(.plain)

                    // MARK: Manage Subscription card (same footprint as others)
                    SubscriptionManagementCard(
                        currentTier: currentTier,
                        hasStripeCustomer: hasStripeSubscription
                    )

                    Spacer(minLength: 56)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)   // ⬅️ no back chevron
        .toolbarBackground(AppTheme.navy900, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            // LEFT — AppShieldSquare (same as MoreView)
            ToolbarItem(placement: .navigationBarLeading) {
                (UIImage(named: "AppShieldSquare") != nil
                 ? Image("AppShieldSquare").resizable().scaledToFit()
                 : Image("four_ps").resizable().scaledToFit())
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.textSecondary.opacity(0.4), lineWidth: 1))
                .padding(4)
                .offset(y: -2)
                .accessibilityHidden(true)
            }

            // CENTER — title
            ToolbarItem(placement: .principal) {
                VStack(spacing: 6) {
                    Text("User Settings")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.bottom, 10)
            }

            // RIGHT — avatar (tap → profile edit)
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
        // 🔁 When the footer’s More tab is tapped again, pop back to MoreView
        .onReceive(NotificationCenter.default.publisher(
            for: Notification.Name("Footer.MoreTabTapped")
        )) { _ in
            dismiss()
        }
        .sheet(isPresented: $showProfileEdit) {
            ProfileEditView()
                .environmentObject(store)
                .environmentObject(session)
        }
    }

    // MARK: - Celebration row helper

    private func settingsRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isOn.wrappedValue },
                set: { newVal in
                    isOn.wrappedValue = newVal
                    onChange(newVal)
                }
            ))
            .labelsHidden()
            .tint(AppTheme.appGreen)
        }
    }
}
