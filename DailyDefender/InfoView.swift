import SwiftUI
import MessageUI

/// HOW TO USE APP — iOS version mirroring Android content exactly.
struct InfoView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    // Header actions
    @State private var showHowToShield = false
    @State private var showProfileEdit = false

    // Collapsible state
    @State private var expandDaily = false
    @State private var expandWeekly = false
    @State private var expandGoals = false
    @State private var expandJournal = false
    @State private var expandResources = false
    @State private var expandProfile = false
    @State private var expandTopLeftBadge = false
    @State private var expandFeedback = false

    // Use project’s square shield for this page (falls back if missing)
    private let howToShieldAsset = "AppShieldSquare"

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navy900.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        // ✅ Daily
                        CollapsibleSection(title: "✅ Daily", isExpanded: $expandDaily) {
                            sectionText("""
Each day, put a check in the checkbox for each quadrant that you have completed an action. If you have any special focus action for that quadrant, like no sugar for instance, put that into the Focused activity entry box.

Daily at midnight your checks will roll into the weekly totals shown on the Weekly screen and then reset so that you start each day fresh. Your Focused activity action will persist until you change it.

For clarity on the 4 quadrants, visit the free Quadrant Course in the Resources page.

Included at the bottom of the screen is a place to list any To Do List items that you want to get done that day or in the coming days.
""")
                        }

                        // 📅 Weekly
                        CollapsibleSection(title: "📅 Weekly", isExpanded: $expandWeekly) {
                            sectionText("""
Use this page to prepare for your squad’s (BOD) weekly check-in.

Reflect on progress and/or issues your facing in each quadrant and capture Wins and Losses. Check whether the week’s One Thing was done or not and choose a new one for the week ahead.

Share this summary during your squad’s (BOD) weekly Zoom call. If you can’t attend the weekly meeting, fill it out anyway and use the Share button at the bottom of the screen to send it to your group (via WhatsApp) so they can offer encouragement and feedback.

Your weekly summary entries reset at the start of a new week on Sunday at midnight.
""")
                        }

                        // 🎯 Goals
                        CollapsibleSection(title: "🎯 Goals", isExpanded: $expandGoals) {
                            sectionText("""
Use Monthly Goals to set clear 30-day goals and track the actions that move the needle forward. Keep it short, visible, and realistic.

Season Goals lets you set bigger 90-day outcomes that matter most.

Review Season goals when you plan your month; review Monthly goals when you plan your week.
""")
                        }

                        // 📝 Journal
                        CollapsibleSection(title: "📝 Journal", isExpanded: $expandJournal) {
                            sectionText("""
Capture thoughts, reflections, and lessons learned in your personal Journal. Each entry is saved with a title and date so you can review growth over time.

You’ll find optional journal outlines like the 10R, Gratitude, and Cage The Wolf to guide your writing when you want more structure or to follow a certain guided process.

Journal entries are private and not shared with your squad.
""")
                        }

                        // 📚 Resources
                        CollapsibleSection(title: "📚 Resources", isExpanded: $expandResources) {
                            sectionText("""
Quick links and guides to support your journey. This area will continue to expand with new tools and training.
""")
                        }

                        // 👤 Profile
                        CollapsibleSection(title: "👤 Profile", isExpanded: $expandProfile) {
                            sectionText("""
Tap your avatar (top right) to update your photo and email. Your photo stays securely stored inside the app.
""")
                        }

                        // 🛡️ Top-Left Badge
                        CollapsibleSection(title: "🛡️ Top-Left Badge", isExpanded: $expandTopLeftBadge) {
                            sectionText("""
The shield in the top-left corner of each screen helps provide key insights for the page you’re on. Tap it and you'll see a quick visual cue that reinforces the page’s purpose.
""")
                        }

                        // 💬 Feedback (button opens email app)
                        CollapsibleSection(title: "💬 Feedback", isExpanded: $expandFeedback) {
                            VStack(alignment: .leading, spacing: 8) {
                                sectionText("""
Use the Share feedback button below to share feedback on the app — whether it’s a bug you’ve found or simply an idea on how to improve the experience. Your input helps us keep making the app better.
""")
                                FeedbackSection()
                            }
                        }

                        Spacer(minLength: 56) // keep clear of global footer
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }

            // === Toolbar (standardized like Daily/Weekly/Goals/More) ===
            .toolbar {
                // Left: Shield icon → FULL SCREEN Cover to ShieldPage
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showHowToShield = true }) {
                        (UIImage(named: howToShieldAsset) != nil
                         ? Image(howToShieldAsset).resizable().scaledToFit()
                         : Image("AppShieldSquare").resizable().scaledToFit()
                        )
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.textSecondary.opacity(0.4), lineWidth: 1))
                        .padding(4)
                        .offset(y: -2) // optical centering
                    }
                    .accessibilityLabel("Open page shield")
                }

                // Center: Title + subtitle (header) with bottom padding inside header
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Text("📖")
                                .font(.system(size: 18, weight: .regular))
                            Text("How To Use App")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        Text("A quick guide to get the most out of this App")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.bottom, 10) // space at bottom of header itself
                }

                // Right: Profile avatar → edit sheet
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

            // Full-screen shield page
            .fullScreenCover(isPresented: $showHowToShield) {
                ShieldPage(
                    imageName: (UIImage(named: howToShieldAsset) != nil ? howToShieldAsset : "AppShieldSquare")
                )
            }

            // Profile sheet
            .sheet(isPresented: $showProfileEdit) {
                ProfileEditView().environmentObject(store)
            }

            // ✅ Reselect-tab listener: if user taps the active "More" tab, pop back.
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("reselectTab"))) { note in
                if let page = note.object as? IosPage, page == .more {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Helpers
    private func sectionText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(AppTheme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Collapsible Section
private struct CollapsibleSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    isExpanded.toggle()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } label: {
                HStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
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

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    content
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.surfaceUI)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppTheme.surfaceUI.opacity(0.35), lineWidth: 1)
                )
                .padding(.top, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}

// MARK: - Feedback Section (email handoff like Android)
private struct FeedbackSection: View {
    @State private var showMailComposer = false
    @State private var mailData = MailData(
        recipients: ["gmanappfeedback@gmail.com"],
        subject: "",
        body: ""
    )
    @State private var showNoMailAlert = false

    private var versionName: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
    }
    private var versionCode: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "?"
    }

    private var subject: String {
        "Daily Defender feedback (iOS) v\(versionName) (\(versionCode))"
    }

    // 🔧 renamed from `body` → `mailBody` to avoid conflict with View.body
    private var mailBody: String {
        let device = UIDevice.current.model
        let system = "iOS \(UIDevice.current.systemVersion)"
        return """
        App: \(versionName) (\(versionCode))
        Device: \(device)
        \(system)

        Please provide feedback or issues noted below:

        """
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                sendFeedback()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "envelope")
                    Text("Send feedback")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.appGreen.opacity(0.18))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Send feedback via email")
        }
        .sheet(isPresented: $showMailComposer) {
            MailView(mailData: mailData) { _ in
                showMailComposer = false
            }
        }
        .alert("No email app found", isPresented: $showNoMailAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please install or set up an email app to send feedback.")
        }
    }

    // MARK: - Flow
    private func sendFeedback() {
        // Prepare mail data
        mailData = MailData(
            recipients: ["gmanappfeedback@gmail.com"],
            subject: subject,
            body: mailBody   // ← updated
        )

        // 1) Apple Mail (MessageUI)
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
            return
        }

        // 2) Gmail (if installed)
        if let gmailURL = gmailComposeURL(to: mailData.recipients, subject: subject, body: mailBody),
           UIApplication.shared.canOpenURL(gmailURL) {
            UIApplication.shared.open(gmailURL)
            return
        }

        // 3) Outlook (if installed)
        if let outlookURL = outlookComposeURL(to: mailData.recipients, subject: subject, body: mailBody),
           UIApplication.shared.canOpenURL(outlookURL) {
            UIApplication.shared.open(outlookURL)
            return
        }

        // 4) Fallback to mailto:
        if let mailto = mailtoURL(to: mailData.recipients, subject: subject, body: mailBody),
           UIApplication.shared.canOpenURL(mailto) {
            UIApplication.shared.open(mailto)
            return
        }

        // 5) Last resort
        showNoMailAlert = true
    }

    // MARK: - URL Builders
    private func gmailComposeURL(to: [String], subject: String, body: String) -> URL? {
        let toStr = to.joined(separator: ",")
        let q = "to=\(toStr)&subject=\(subject)&body=\(body)"
        let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "googlegmail://co?\(encoded)") ?? URL(string: "gmail://co?\(encoded)")
    }

    private func outlookComposeURL(to: [String], subject: String, body: String) -> URL? {
        let toStr = to.joined(separator: ",")
        let q = "to=\(toStr)&subject=\(subject)&body=\(body)"
        let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "ms-outlook://compose?\(encoded)")
    }

    private func mailtoURL(to: [String], subject: String, body: String) -> URL? {
        let toStr = to.joined(separator: ",")
        let s = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let b = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:\(toStr)?subject=\(s)&body=\(b)")
    }
}

// MARK: - MailView wrapper (Apple Mail)
private struct MailData {
    var recipients: [String]
    var subject: String
    var body: String
    var attachments: [MailAttachment] = []
}
private struct MailAttachment {
    var data: Data
    var mimeType: String
    var fileName: String
}

private struct MailView: UIViewControllerRepresentable {
    var mailData: MailData
    var onResult: (Result<MFMailComposeResult, Error>) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients(mailData.recipients)
        vc.setSubject(mailData.subject)
        vc.setMessageBody(mailData.body, isHTML: false)
        for a in mailData.attachments {
            vc.addAttachmentData(a.data, mimeType: a.mimeType, fileName: a.fileName)
        }
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onResult: (Result<MFMailComposeResult, Error>) -> Void
        init(onResult: @escaping (Result<MFMailComposeResult, Error>) -> Void) { self.onResult = onResult }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            if let error = error {
                onResult(.failure(error))
            } else {
                onResult(.success(result))
            }
            controller.dismiss(animated: true)
        }
    }
}
