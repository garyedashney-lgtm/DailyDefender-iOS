import SwiftUI
import UIKit

// MARK: - FeedbackSection (drop-in)
private struct FeedbackSection: View {
    @State private var feedbackText: String = ""
    @State private var showShareSheet = false

    private var versionName: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
    }
    private var versionCode: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Share feedback on bugs or ideas. Your notes will be included below.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)

            // Input
            ZStack(alignment: .topLeading) {
                if feedbackText.isEmpty {
                    Text("Type your feedback…")
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                TextEditor(text: $feedbackText)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.navy900.opacity(0.4))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.surfaceUI.opacity(0.35), lineWidth: 1)
                    )
                    .foregroundStyle(AppTheme.textPrimary)
                    .scrollContentBackground(.hidden)
            }

            HStack {
                Text("\(feedbackText.count) chars")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Button {
                    showShareSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Feedback")
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
                .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            let body =
            """
            Feedback for ATM Defender App
            v\(versionName) (\(versionCode))

            \(feedbackText)
            """
            ShareSheet(activityItems: [body])
        }
    }
}

// MARK: - UIKit Share Sheet Wrapper
private struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
