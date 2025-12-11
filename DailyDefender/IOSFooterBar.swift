import SwiftUI
import Foundation

private extension Notification.Name {
    static let reselectTab = Notification.Name("reselectTab")
}

enum IosPage: Hashable { case daily, weekly, goals, journal, more }

struct IOSFooterBar: View {
    let currentPage: IosPage
    let onSelectPage: (IosPage) -> Void
    let versionName: String
    let versionCode: String
    let weekKey: String

    private var unselectedTint: Color { Color.white.opacity(0.72) }
    private var selectedTint: Color { AppTheme.appGreen }
    private var footerFont: Font { .system(size: 11, weight: .regular) }

    @ViewBuilder
    private func Item(_ page: IosPage, label: String, systemName: String) -> some View {
        let selected = (currentPage == page)
        let tint = selected ? selectedTint : unselectedTint

        VStack(spacing: 2) {
            Image(systemName: systemName)
                .imageScale(.medium)
                .foregroundStyle(tint)
            Text(label)
                .font(footerFont)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .contentShape(Rectangle())
        .onTapGesture {
            if page == currentPage {
                // Reselect on same tab
                NotificationCenter.default.post(name: .reselectTab, object: page)

                // Special: if Journal is reselected, jump back to JournalHome.
                if page == .journal {
                    NotificationCenter.default.post(name: .JumpToJournalHome, object: nil)
                }

                // 🔹 NEW: if More is reselected, tell whoever is on the More stack
                // (Info, Resources, Stats, UserSettingsScreen) to dismiss back to More.
                if page == .more {
                    NotificationCenter.default.post(
                        name: Notification.Name("Footer.MoreTabTapped"),
                        object: nil
                    )
                }
            } else {
                onSelectPage(page)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(label))
    }

    var body: some View {
        let isDev = Bundle.main.isDev

        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)

            // Row 1: icons + labels
            HStack(spacing: 0) {
                Item(.daily,   label: "Daily",   systemName: "checkmark.square")
                Item(.weekly,  label: "Weekly",  systemName: "calendar")
                Item(.goals,   label: "Goals",   systemName: "target")
                Item(.journal, label: "Journal", systemName: "book")
                Item(.more,    label: "More",    systemName: "line.3.horizontal")
            }
            .padding(.horizontal, 6)

            // Row 2: app/version + ISO week + DEV badge (only on dev target)
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text("ATM Defender App")
                        .font(footerFont)
                        .foregroundStyle(Color.white.opacity(0.72))

                    if isDev {
                        Text("DEV")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.red.opacity(0.95))
                            .clipShape(Capsule())
                            .foregroundStyle(.white)
                            .accessibilityLabel(Text("Development build"))
                    }
                }

                Spacer()

                Text("v\(versionName) (\(versionCode)) • \(weekKey)")
                    .font(footerFont)
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .frame(height: 24)
            .padding(.horizontal, 12)
        }
        .background(AppTheme.navy900)
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: -2)
        .ignoresSafeArea(edges: .bottom)
    }
}
