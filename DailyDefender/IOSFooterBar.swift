import SwiftUI

enum IosPage: Hashable {
    case daily, weekly, monthly, seasons, more
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
        .frame(maxWidth: .infinity, minHeight: 56)  // match Android item height
        .contentShape(Rectangle())
        .onTapGesture { onSelectPage(page) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(label))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Thin top separator
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)

            // Row 1: icons + labels (SF Symbols chosen to mirror Material)
            HStack(spacing: 0) {
                Item(.daily,   label: "Daily",   systemName: "checkmark.square")       // FactCheck
                Item(.weekly,  label: "Weekly",  systemName: "calendar")                // DateRange
                Item(.monthly, label: "Monthly", systemName: "calendar.badge.plus")     // CalendarMonth analog
                Item(.seasons, label: "Seasons", systemName: "sun.max")                 // WbSunny
                Item(.more,    label: "More",    systemName: "line.3.horizontal")       // Dehaze
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
        .background(AppTheme.navy900)       // darker band like Android
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: -2) // subtle lift
        .ignoresSafeArea(edges: .bottom)
    }
}
