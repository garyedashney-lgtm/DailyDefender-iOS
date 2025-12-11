import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct PaywallCardView: View {
    /// Title passed from RootView:
    /// - "Requires Standard Subscription"  (Weekly / Goals)
    /// - "Requires Pro Subscription"       (Journal)
    var title: String

    @Environment(\.openURL) private var openURL

    @State private var isOpening = false
    @State private var errorMessage: String?
    @State private var showError = false

    // 🔗 URLs
    private let checkoutURLString = "https://10mm.org/app-checkout"
    // Your live Stripe **customer portal login** URL
    private let stripePortalURLString =
        "https://billing.stripe.com/p/login/9B68wQachdMn6uIaLG8EM00"

    // MARK: - Derived subtitle

    private var subtitle: String {
        let lowered = title.lowercased()

        if lowered.contains("standard") {
            return "This page is part of the Defender Standard subscription."
        } else if lowered.contains("pro") {
            return "This page is part of the Defender Pro subscription."
        } else {
            return "This page requires a Defender subscription."
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            VStack(spacing: 20) {
                // Title
                Text(title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.textPrimary)

                // Shield / brand image
                Group {
                    if UIImage(named: "AppShieldSquare") != nil {
                        Image("AppShieldSquare")
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "shield.lefthalf.filled")
                            .resizable()
                            .scaledToFit()
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(AppTheme.appGreen, AppTheme.navy900)
                    }
                }
                .frame(width: 110, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)

                // Subtitle / explainer
                Text(subtitle)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(3)

                Text("Upgrade to unlock this page—plus full access to the Defender experience.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.9))
                    .padding(.top, 2)

                // Upgrade button — SMART:
                // - Stripe customer? → Stripe portal
                // - Not Stripe yet?  → Wallace checkout
                Button {
                    handleUpgradeTapped()
                } label: {
                    HStack {
                        if isOpening {
                            ProgressView()
                                .tint(AppTheme.appGreen)
                            Text("Opening…")
                        } else {
                            Text("Upgrade Subscription")
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "arrow.up.right.square")
                            .imageScale(.medium)
                    }
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.appGreen)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                }
                .disabled(isOpening)
                .padding(.top, 4)

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
        }
        .alert("Billing Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                showError = false
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "Something went wrong opening your subscription options.")
        }
    }

    // MARK: - Actions

    /// Smart upgrade handler:
    /// - If the user has a stripeCustomerId in Firestore → Stripe portal
    /// - Otherwise → Wallace checkout
    private func handleUpgradeTapped() {
        // If there's no signed-in Firebase user, just send to checkout.
        guard let user = Auth.auth().currentUser else {
            openCheckout()
            return
        }

        isOpening = true
        errorMessage = nil
        showError = false

        Task {
            do {
                let db = Firestore.firestore()
                let snapshot = try await db.collection("users")
                    .document(user.uid)
                    .getDocument()

                let data = snapshot.data() ?? [:]
                let stripeCustomerId = (data["stripeCustomerId"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let hasStripeCustomer =
                    (stripeCustomerId?.isEmpty == false)

                let targetURLString = hasStripeCustomer
                    ? stripePortalURLString
                    : checkoutURLString

                await open(urlString: targetURLString)
            } catch {
                // On any error, be graceful and send them to checkout.
                await MainActor.run {
                    errorMessage = nil // don't scare the user, just fallback
                }
                await open(urlString: checkoutURLString)
            }

            await MainActor.run {
                isOpening = false
            }
        }
    }

    // MARK: - URL helpers

    private func openCheckout() {
        if let url = URL(string: checkoutURLString) {
            openURL(url)
        } else {
            errorMessage = "Unable to open checkout page."
            showError = true
        }
    }

    @MainActor
    private func open(urlString: String) async {
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid billing URL."
            showError = true
            return
        }
        openURL(url)
    }
}
