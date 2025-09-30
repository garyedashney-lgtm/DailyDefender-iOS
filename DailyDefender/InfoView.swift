import SwiftUI

struct InfoView: View {
    private let FEEDBACK_EMAIL = "feedback@example.com"

    var body: some View {
        BrandShieldHost { onLeftTap in
            ZStack {
                AppTheme.navy900.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        // Daily
                        EmojiSectionHeader(label: "Daily Screen", emoji: "✅")
                        Text("Check off your 8 key actions daily across all 4 quadrants (2 actions each). Your daily checks will auto-roll into the weekly totals at midnight. If you need more clarity on the 4 quadrants, check out the free Quadrant Course found in the Resources page.")
                            .font(.body)
                            .foregroundStyle(AppTheme.textSecondary)

                        // Weekly
                        EmojiSectionHeader(label: "Weekly Check-In", emoji: "📅")
                        Text("Check in with your tribe of men weekly. Note your progress for the week, jot notes in each quadrant section, capture Wins/Losses, pick One Thing for next week, and share a weekly summary.")
                            .font(.body)
                            .foregroundStyle(AppTheme.textSecondary)

                        // Resources
                        EmojiSectionHeader(label: "Resources", emoji: "📚")
                        Text("Quick links and guides. We’ll expand this area with more tools.")
                            .font(.body)
                            .foregroundStyle(AppTheme.textSecondary)

                        // Ask Wally
                        EmojiSectionHeader(label: "Ask Wally", emoji: "🤖")
                        Text("This is an AI persona of Advisor to Men (Wally). Ask questions in your own words. Keep it short and specific for best results. It will respond based off Wally’s corpus. (We’ll evolve and improve this over time.)")
                            .font(.body)
                            .foregroundStyle(AppTheme.textSecondary)

                        // Profile
                        EmojiSectionHeader(label: "Profile", emoji: "👤")
                        Text("Tap your avatar (top right) to update your photo and email. Your photo is stored securely inside the app.")
                            .font(.body)
                            .foregroundStyle(AppTheme.textSecondary)

                        // Feedback
                        EmojiSectionHeader(label: "Feedback", emoji: "💬")
                        FeedbackSection(
                            email: FEEDBACK_EMAIL,
                            diagnostics: "\(Bundle.main.appVersion) (\(Bundle.main.appBuild)) • \(currentWeekKey())"
                        )

                        // Extra breathing room so the last element clears the footer on overscroll
                        Spacer().frame(height: 8)
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                    // Ensure the last button never hides behind the footer (matches DailyView)
                    .padding(.bottom, 48)
                }
            }
            // Top header (updated: shield on left, tappable)
            .safeAreaInset(edge: .top) {
                AppHeaderBar(
                    title: "Info",
                    subtitle: "A quick guide to get the most out of this App",
                    centerEmoji: "📖",
                    appLogoName: "AppShieldSquare",     // use the square shield asset
                    profileAsset: nil,
                    onLeftTap: { onLeftTap() }           // <- open brand page
                )
                .padding(.top, 4)
                .padding(.horizontal, 16)
                .background(AppTheme.navy900)
            }
            // Bottom inset to match DailyView so content clears your custom footer
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 48)
            }
        }
    }
}

// MARK: - Helpers

private struct FeedbackSection: View {
    let email: String
    let diagnostics: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("We’d love your feedback or bug reports. Sending from the app helps us improve quickly.")
                .font(.body)
                .foregroundStyle(AppTheme.textSecondary)

            Button {
                openMail(
                    to: email,
                    subject: "ATM 10MM App Feedback",
                    body: """
                    Hi Team,

                    Feedback:
                    • What happened:
                    • Steps to reproduce:
                    • Expected vs actual:

                    Diagnostics: \(diagnostics)
                    """
                )
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane")
                    Text("Send Feedback")
                        .font(.callout.weight(.semibold))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white, lineWidth: 1) // outlined, no fill
                )
                .foregroundStyle(.white)
            }
        }
        .padding(.vertical, 6) // matches other sections
    }

    private func openMail(to: String, subject: String, body: String) {
        let subj = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:\(to)?subject=\(subj)&body=\(body)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview { InfoView() }
