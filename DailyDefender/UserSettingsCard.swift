import SwiftUI

// MARK: - Shared celebration settings backing store

struct CelebrationSettings {
    private static let keyConfetti = "enable_confetti"
    private static let keyAudio    = "enable_audio"
    private static let keyVideo    = "enable_video"

    static var isConfettiEnabled: Bool {
        get { UserDefaults.standard.object(forKey: keyConfetti) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: keyConfetti) }
    }

    static var isAudioEnabled: Bool {
        get { UserDefaults.standard.object(forKey: keyAudio) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: keyAudio) }
    }

    static var isVideoEnabled: Bool {
        get { UserDefaults.standard.object(forKey: keyVideo) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: keyVideo) }
    }
}

/// Full User Settings content (Celebration, Profile, Subscription)
/// This is now **screen content only** – no outer "User Settings" header card.
struct UserSettingsCard: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.openURL) private var openURL

    /// Canonical tier from Firestore: "free", "amateur", or "pro"
    let currentTier: String

    /// Whether this user already has a Stripe customer record
    /// (comes from `session.hasStripeSubscription`)
    let hasStripeSubscription: Bool

    /// Called when the user taps "Update Profile"
    let onEditProfile: () -> Void

    // Celebration toggles
    @State private var confettiOn = CelebrationSettings.isConfettiEnabled
    @State private var audioOn    = CelebrationSettings.isAudioEnabled
    @State private var videoOn    = CelebrationSettings.isVideoEnabled

    // Billing portal state
    @State private var isManagingBilling = false
    @State private var billingError: String?
    @State private var isShowingError = false

    // MARK: - Tier helpers

    private var tierLabel: String {
        switch currentTier.lowercased() {
        case "pro": return "Pro"
        case "amateur": return "Standard"
        default: return "Free"
        }
    }

    private var tierSubtitle: String {
        switch currentTier.lowercased() {
        case "pro":
            return "Full access to Daily, Weekly, Goals, and Journal."
        case "amateur":
            return "Standard tier: full Daily/Weekly/Goals. Journal locked."
        default:
            return "Free tier: core Daily tools only. Upgrade to unlock more."
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // 1) Celebration Settings card (always expanded on this screen)
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
                }

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
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.surfaceUI)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
            )

            // 2) Update Profile card
            Button(action: onEditProfile) {
                HStack(spacing: 12) {
                    // Avatar bubble
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

            // 3) Subscription & Billing card
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.navy900.opacity(0.35))
                            .frame(width: 32, height: 32)
                        Image(systemName: "creditcard")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.appGreen)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Subscription & Billing")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Current tier: \(tierLabel)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                }

                Text(tierSubtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    openBillingDestination()
                } label: {
                    HStack {
                        if isManagingBilling {
                            ProgressView().tint(AppTheme.appGreen)
                            Text("Opening…")
                        } else {
                            Text("Manage Subscription")
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .imageScale(.medium)
                    }
                    .font(.footnote.weight(.semibold))
                }
                .disabled(isManagingBilling)
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.surfaceUI)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
            )
        }
        .alert("Billing Error", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {
                billingError = nil
            }
        } message: {
            Text(billingError ?? "Something went wrong opening the billing portal.")
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

    // MARK: - Billing destination

    /// Mirrors the same logic we use on the paywall:
    /// - If user has a Stripe customer → open Stripe portal (manage)
    /// - Otherwise → send to Wallace's checkout page (buy for first time)
    private func openBillingDestination() {
        isManagingBilling = true
        billingError = nil
        isShowingError = false

        // LIVE URLs
        let portalURLString   = "https://billing.stripe.com/p/login/9B68wQachdMn6uIaLG8EM00"
        let checkoutURLString = "https://10mm.org/app-checkout"

        let targetString = hasStripeSubscription ? portalURLString : checkoutURLString

        guard let url = URL(string: targetString) else {
            billingError = "Unable to open billing URL."
            isShowingError = true
            isManagingBilling = false
            return
        }

        // Tiny delay so the spinner can show
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            openURL(url)
            isManagingBilling = false
        }
    }
}
