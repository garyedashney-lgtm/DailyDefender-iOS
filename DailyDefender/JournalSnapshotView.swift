import SwiftUI

struct JournalSnapshotView: View {
    let entry: JournalEntryIOS
    @Environment(\.dismiss) private var dismiss

    private var createdDate: Date { Date(timeIntervalSince1970: TimeInterval(entry.dateMillis) / 1000.0) }
    private var updatedDate: Date { Date(timeIntervalSince1970: TimeInterval(entry.updatedAt) / 1000.0) }

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Title
                    Text(entry.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    // Created/Updated (subtle)
                    HStack(spacing: 10) {
                        Text("Created \(dateOnlyLabel(createdDate))")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text("Updated \(dateOnlyLabel(updatedDate))")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.9))
                        Spacer()
                    }

                    // Body (read-only)
                    Text(entry.content.isEmpty ? "—" : entry.content)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.surfaceUI))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.textSecondary.opacity(0.15), lineWidth: 1))

                    // Bottom actions: Back only (no edit/save)
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Text("Back")
                                .font(.title3.weight(.semibold))
                                .frame(height: 42)
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.white)
                        .buttonBorderShape(.roundedRectangle(radius: 12))
                    }
                    .padding(.top, 6)

                    Spacer(minLength: 56)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .toolbar {
            // Minimal toolbar: title only
            ToolbarItem(placement: .principal) {
                Text("Journal")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.bottom, 10)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.navy900, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 48) }
    }
}

// Local helper (same format you used elsewhere)
private func dateOnlyLabel(_ date: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "EEE, MMM d, yyyy"
    return f.string(from: date)
}

