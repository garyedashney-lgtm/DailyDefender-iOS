import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MoreView: View {
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    // Nav pushes
    @State private var goInfo = false
    @State private var goResources = false
    @State private var goStats = false
    @State private var goUserSettings = false   // 🔹 new

    // Header actions
    @State private var showProfileEdit = false
    @State private var showShield = false

    // Current app tier for settings ("free", "amateur", "pro")
    @State private var currentTier: String = "free"

    // Whether this user has / had a Stripe subscription
    @State private var hasStripeSubscription: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navy900.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {

                        // 🔹 Cards only (no extra "More" + compass row)
                        MoreCardRow(title: "How To Use App", emoji: "📖") {
                            goInfo = true
                        }

                        MoreCardRow(title: "Resources", emoji: "📚") {
                            goResources = true
                        }

                        // 🔹 User Settings row → pushes full screen
                        MoreCardRow(title: "User Settings", emoji: "⚙️") {
                            goUserSettings = true
                        }

                        MoreCardRow(title: "Stats", emoji: "📊") {
                            goStats = true
                        }

                        Spacer(minLength: 56)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.navy900, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                // LEFT — shield asset
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showShield = true }) {
                        (UIImage(named: "AppShieldSquare") != nil
                         ? Image("AppShieldSquare").resizable().scaledToFit()
                         : Image("four_ps").resizable().scaledToFit())
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(
                                AppTheme.textSecondary.opacity(0.4),
                                lineWidth: 1
                            )
                        )
                        .padding(4)
                        .offset(y: -2)
                    }
                    .accessibilityLabel("Open page shield")
                }

                // CENTER — title
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 6) {
                        Text("More")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(.bottom, 10)
                }

                // RIGHT — avatar → ProfileEdit
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
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 48) }

            // Destinations
            .navigationDestination(isPresented: $goInfo) {
                InfoView()
                    .environmentObject(store)
                    .environmentObject(session)
                    .onReceive(
                        NotificationCenter.default.publisher(
                            for: Notification.Name("Footer.MoreTabTapped")
                        )
                    ) { _ in
                        dismiss()
                    }
            }
            .navigationDestination(isPresented: $goResources) {
                ResourcesView()
                    .environmentObject(store)
                    .environmentObject(session)
                    .onReceive(
                        NotificationCenter.default.publisher(
                            for: Notification.Name("Footer.MoreTabTapped")
                        )
                    ) { _ in
                        dismiss()
                    }
            }
            .navigationDestination(isPresented: $goStats) {
                StatsView()
                    .environmentObject(store)
                    .environmentObject(session)
                    .onReceive(
                        NotificationCenter.default.publisher(
                            for: Notification.Name("Footer.MoreTabTapped")
                        )
                    ) { _ in
                        dismiss()
                    }
            }
            // 🔹 User Settings screen
            .navigationDestination(isPresented: $goUserSettings) {
                UserSettingsScreen(
                    currentTier: currentTier,
                    hasStripeSubscription: hasStripeSubscription
                )
                .environmentObject(store)
                .environmentObject(session)
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: Notification.Name("Footer.MoreTabTapped")
                    )
                ) { _ in
                    dismiss()
                }
            }

            // Sheets
            .fullScreenCover(isPresented: $showShield) {
                ShieldPage(imageName: "AppShieldSquare")
            }
            .sheet(isPresented: $showProfileEdit) {
                ProfileEditView()
                    .environmentObject(store)
                    .environmentObject(session)
            }
            .onAppear {
                Task { await refreshTierFromFirebase() }
            }
        }
    }
}

// MARK: - Card Row (matches Journal look)
private struct MoreCardRow: View {
    let title: String
    let emoji: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.appGreen.opacity(0.16))
                        .frame(width: 40, height: 40)
                    Text(emoji)
                        .font(.system(size: 20))
                }

                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

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

// MARK: - Firebase tier + Stripe status fetch

extension MoreView {
    /// Reads the user's tier from Firestore and normalizes it to: "free" | "amateur" | "pro"
    /// Also sets `hasStripeSubscription` if a stripeCustomerId is present.
    private func refreshTierFromFirebase() async {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()

        do {
            let snapshot = try await db.collection("users").document(user.uid).getDocument()

            var tier: String = "free"
            var hasStripe = false

            if let data = snapshot.data() {
                // Tier normalization
                if let rawTier = (data["tier"] as? String) ??
                                 (data["appLevel"] as? String) ??
                                 (data["plan"] as? String) {
                    let normalized = rawTier.uppercased()
                    switch normalized {
                    case "FREE": tier = "free"
                    case "AMATEUR", "STANDARD": tier = "amateur"
                    case "PRO": tier = "pro"
                    default: tier = rawTier.lowercased()
                    }
                }

                // Stripe customer id present?
                if let stripeId = data["stripeCustomerId"] as? String,
                   !stripeId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    hasStripe = true
                }
            }

            await MainActor.run {
                self.currentTier = tier
                self.hasStripeSubscription = hasStripe
            }
        } catch {
            print("refreshTierFromFirebase (MoreView) error:", error.localizedDescription)
        }
    }
}

// MARK: - Notification helper

private extension Notification.Name {
    static let reselectTab = Notification.Name("reselectTab")
}
