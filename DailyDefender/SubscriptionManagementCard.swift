import SwiftUI

/// Card that routes the user either to:
///  - Stripe Billing Portal (if they already have a Stripe customer)
///  - Wallace's app checkout page (if they don't)
struct SubscriptionManagementCard: View {
    /// Canonical tier from Firestore: "free", "amateur", or "pro"
    let currentTier: String

    /// True if this user already has a Stripe customer/subscription record.
    let hasStripeCustomer: Bool

    @Environment(\.openURL) private var openURL

    @State private var isManagingBilling = false
    @State private var billingError: String?
    @State private var isShowingError = false

    private var tierLabel: String {
        switch currentTier.lowercased() {
        case "pro":
            return "Pro"
        case "amateur":
            return "Standard"
        default:
            return "Free"
        }
    }

    var body: some View {
        Button {
            openBillingPortal()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.navy900.opacity(0.35))
                        .frame(width: 32, height: 32)
                    Image(systemName: "creditcard")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.appGreen)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Manage Subscription")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Current tier: \(tierLabel)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                if isManagingBilling {
                    ProgressView()
                        .tint(AppTheme.appGreen)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.surfaceUI)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(.plain)
        .alert("Billing Error", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {
                billingError = nil
            }
        } message: {
            Text(billingError ?? "Something went wrong opening the billing portal.")
        }
    }

    // MARK: - Actions

    private func openBillingPortal() {
        // Stripe portal for existing customers,
        // Wallace checkout for brand new ones.
        let urlString: String

        if hasStripeCustomer {
            // 🔐 Live Stripe billing portal (existing subscribers)
            urlString = "https://billing.stripe.com/p/login/9B68wQachdMn6uIaLG8EM00"
        } else {
            // 🌐 Wallace checkout page (brand new / never subscribed)
            urlString = "https://10mm.org/app-checkout"
        }

        guard let url = URL(string: urlString) else {
            billingError = "Unable to open billing portal URL."
            isShowingError = true
            return
        }

        isManagingBilling = true
        billingError = nil
        isShowingError = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            openURL(url)
            isManagingBilling = false
        }
    }
}
