import SwiftUI

// Notif used to tell child screens to pop when user re-taps the active tab (e.g., More)
private extension Notification.Name {
    static let reselectTab = Notification.Name("reselectTab")
}

enum IosPage: Hashable {
    case daily, weekly, goals, journal, more
}

struct IOSFooterBar: View {
    let currentPage: IosPage
    let onSelectPage: (IosPage) -> Void
    let versionName: String
    let versionCode: String
    let weekKey: String

    private var unselectedTint: Color { Color.white.opacity(0.72) }
    private var selectedTint: Color { AppTheme.appGreen } // brand green, like Android
    private var footerFont: Font { .system(size: 11, weight: .regular) } // Android labelSmall ~11sp

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
        .frame(maxWidth: .infinity, minHeight: 56) // match Android item height
        .contentShape(Rectangle())
        .onTapGesture {
            if page == currentPage {
                // Re-tapped the active tab: broadcast so nested stacks can pop to root.
                NotificationCenter.default.post(name: .reselectTab, object: page)
            } else {
                // Normal tab switch.
                onSelectPage(page)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(label))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Thin top separator
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)

            // Row 1: icons + labels (mirrors Android order)
            HStack(spacing: 0) {
                Item(.daily,   label: "Daily",   systemName: "checkmark.square")     // FactCheck analog
                Item(.weekly,  label: "Weekly",  systemName: "calendar")              // DateRange analog
                Item(.goals,   label: "Goals",   systemName: "target")                // TrackChanges analog
                Item(.journal, label: "Journal", systemName: "book")                  // MenuBook analog
                Item(.more,    label: "More",    systemName: "line.3.horizontal")     // Dehaze analog
            }
            .padding(.horizontal, 6)

            // Row 2: app/version + ISO week
            HStack {
                Text("ATM 10MM App")
                    .font(footerFont)
                    .foregroundStyle(Color.white.opacity(0.72))
                Spacer()
                Text("v\(versionName) (\(versionCode)) • \(weekKey)")
                    .font(footerFont)
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .frame(height: 24)
            .padding(.horizontal, 12)
        }
        .background(AppTheme.navy900) // darker band like Android
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: -2)
        .ignoresSafeArea(edges: .bottom)
    }
}
