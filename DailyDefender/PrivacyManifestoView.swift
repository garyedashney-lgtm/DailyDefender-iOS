import SwiftUI

struct PrivacyManifestoView: View {

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Title
                    Text("🔒 App Privacy Manifesto")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)

                    // Body – easy to tweak later if Wallace changes wording
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your inner world belongs to you.")

                        Text("This app stores your journal entries, goals, stats, and notes on your device.")

                        Text("The only items uploaded to a centralized server are your user name, email, daily checkmarks, tier level, and squad assignment.")

                        Text("Nothing else is shared with Advisor to Men or anyone else.")

                        Text("No coach, admin, or system can read your thoughts.")

                        Text("What you write here is your territory — protected and private.")

                        Text("If you ever want a copy, you choose when and where to export it through the Share features built into the app. No one else has access.")

                        Text("This app is a tool for your growth — not a window into your mind.")

                        Text("Your privacy is absolute.")

                        Text("Your sovereignty is respected.")

                        Text("— Advisor to Men™️")
                            .padding(.top, 8)
                    }
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                // 👇 This is the important bit: gives room so the last line can scroll above any footer / home indicator
                .padding(.bottom, 120)
            }
        }
        .navigationTitle("App Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
