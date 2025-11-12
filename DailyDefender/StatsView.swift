import SwiftUI
import Foundation

// MARK: - Footer navigation signal (match your FooterBar)
extension Notification.Name {
    /// Posted when the Footer "More" icon is tapped.
    static let moreTabTapped = Notification.Name("Footer.MoreTabTapped")
}

// MARK: - Stats View (iOS) — mirrors Android "All 4 Ps" stats using daily snapshots
struct StatsView: View {
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    // UI
    @State private var showFourPs = false
    @State private var goProfileEdit = false

    // Theme helpers
    private var todayStringYMD: String {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navy900.ignoresSafeArea()

                List {
                    // Header (centered, no subtext)
                    Section {
                        VStack(spacing: 8) {
                            Text("Daily Defender Activity")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }
                    .listRowBackground(AppTheme.surface)

                    // Activity table (with totals)
                    Section {
                        DailyDefenderActivityCard()
                            .environmentObject(store)
                            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(AppTheme.navy900)
                    }

                    // spacer
                    Section { Color.clear.frame(height: 24) }
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.navy900)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .modifier(CompactListTweaks())
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true) // ⬅️ no back chevron
            .toolbarBackground(AppTheme.navy900, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                // LEFT — 4Ps shield (not a back button)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showFourPs = true }) {
                        Image("four_ps")
                            .resizable().scaledToFit()
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppTheme.textSecondary.opacity(0.4), lineWidth: 1))
                            .padding(4)
                            .offset(y: -2)
                    }
                    .accessibilityLabel("Open 4 Ps Shield")
                }

                // CENTER — Title/date
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        HStack(spacing: 8) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.appGreen)
                            Text("Stats")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1).minimumScaleFactor(0.9)
                        }
                        Text("Today: \(todayStringYMD)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(.bottom, 6)
                    }
                }

                // RIGHT — Avatar → profile
                ToolbarItem(placement: .navigationBarTrailing) {
                    Group {
                        if let path = store.profile.photoPath, let ui = UIImage(contentsOfFile: path) {
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
                    .onTapGesture { goProfileEdit = true }
                    .accessibilityLabel("Profile")
                }
            }
            .fullScreenCover(isPresented: $showFourPs) {
                ShieldPage(imageName: "four_ps")
            }
            NavigationLink("", isActive: $goProfileEdit) {
                ProfileEditView().environmentObject(store).environmentObject(session)
            }.hidden()

            // === Footer wiring: tapping "More" should pop to More screen ===
            .onReceive(NotificationCenter.default.publisher(for: .moreTabTapped)) { _ in
                dismiss()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("reselectTab"))) { note in
                if let page = note.object as? IosPage, page == .more {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Activity Card (table with emojis + totals)
private struct DailyDefenderActivityCard: View {
    @EnvironmentObject var store: HabitStore

    // Pillar flag ids — must match DailyView / Android
    private let physId = "pillar_phys"
    private let pietyId = "pillar_piety"
    private let peopleId = "pillar_people"
    private let prodId = "pillar_prod"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack {
                Text("Quadrant")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("7 Day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 64, alignment: .trailing)
                Text("30 Day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 64, alignment: .trailing)
                Text("60 Day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 64, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            // Data rows (exact look you asked for)
            VStack(spacing: 6) {
                tableRow("🛡️ All 4P’s Done", allFour: true)
                tableRow("💪 Physiology", flag: physId)
                tableRow("🙏 Piety", flag: pietyId)
                tableRow("👥 People", flag: peopleId)
                tableRow("🧰 Production", flag: prodId)

                // Totals (sum of all rows above, including All-4Ps)
                totalsRow()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.surfaceUI)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - One row
    @ViewBuilder
    private func tableRow(_ title: String, flag: String? = nil, allFour: Bool = false) -> some View {
        HStack(spacing: 4) {
            // First column
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(minWidth: 120, alignment: .leading)

            Spacer(minLength: 6)

            // Numeric columns
            let v7   = allFour ? countAll4PInLastNDays(7)  : countPillarInLastNDays(flag: flag!, n: 7)
            let v30  = allFour ? countAll4PInLastNDays(30) : countPillarInLastNDays(flag: flag!, n: 30)
            let v60  = allFour ? countAll4PInLastNDays(60) : countPillarInLastNDays(flag: flag!, n: 60)

            Text("\(v7)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 64, alignment: .trailing)
            Text("\(v30)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 64, alignment: .trailing)
            Text("\(v60)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 64, alignment: .trailing)
        }
    }

    // MARK: - Totals row
    @ViewBuilder
    private func totalsRow() -> some View {
        // compute all values once
        let all4_7   = countAll4PInLastNDays(7)
        let phys_7   = countPillarInLastNDays(flag: physId, n: 7)
        let piety_7  = countPillarInLastNDays(flag: pietyId, n: 7)
        let people_7 = countPillarInLastNDays(flag: peopleId, n: 7)
        let prod_7   = countPillarInLastNDays(flag: prodId, n: 7)

        let all4_30   = countAll4PInLastNDays(30)
        let phys_30   = countPillarInLastNDays(flag: physId, n: 30)
        let piety_30  = countPillarInLastNDays(flag: pietyId, n: 30)
        let people_30 = countPillarInLastNDays(flag: peopleId, n: 30)
        let prod_30   = countPillarInLastNDays(flag: prodId, n: 30)

        let all4_60   = countAll4PInLastNDays(60)
        let phys_60   = countPillarInLastNDays(flag: physId, n: 60)
        let piety_60  = countPillarInLastNDays(flag: pietyId, n: 60)
        let people_60 = countPillarInLastNDays(flag: peopleId, n: 60)
        let prod_60   = countPillarInLastNDays(flag: prodId, n: 60)

        let total7  = all4_7  + phys_7  + piety_7  + people_7  + prod_7
        let total30 = all4_30 + phys_30 + piety_30 + people_30 + prod_30
        let total60 = all4_60 + phys_60 + piety_60 + people_60 + prod_60

        // visual divider that pops a bit more
        Rectangle()
            .fill(AppTheme.textSecondary.opacity(0.45))
            .frame(height: 1)
            .padding(.vertical, 6)

        HStack(spacing: 4) {
            Text("Total")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.appGreen)
                .frame(minWidth: 120, alignment: .leading)
            Spacer(minLength: 6)
            Text("\(total7)")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(AppTheme.appGreen)
                .frame(width: 64, alignment: .trailing)
            Text("\(total30)")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(AppTheme.appGreen)
                .frame(width: 64, alignment: .trailing)
            Text("\(total60)")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(AppTheme.appGreen)
                .frame(width: 64, alignment: .trailing)
        }
    }

    // MARK: - Rolling-window logic (snapshot parity)
    private func lastNDateKeys(_ n: Int) -> [String] {
        let cal = Calendar(identifier: .gregorian)
        let df = DateFormatter()
        df.calendar = cal
        df.dateFormat = "yyyyMMdd"
        return (0..<n).map { i in
            let d = cal.date(byAdding: .day, value: -i, to: Date())!
            return df.string(from: d)
        }
    }

    private func todayKey() -> String {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.dateFormat = "yyyyMMdd"
        return df.string(from: Date())
    }

    /// Pull per-day snapshot from UserDefaults; for *today* fall back to live set in `store.completed`.
    private func perDayCompletedOrLive(_ dateKey: String) -> Set<String> {
        if let snap = UserDefaults.standard.array(forKey: "daily_completed_\(dateKey)") as? [String] {
            return Set(snap)
        }
        if dateKey == todayKey() {
            return store.completed
        }
        return []
    }

    /// True if day has all 4 pillar flags.
    private func dayHasAllFourPs(_ perDay: Set<String>) -> Bool {
        perDay.contains(physId) &&
        perDay.contains(pietyId) &&
        perDay.contains(peopleId) &&
        perDay.contains(prodId)
    }

    /// Rolling count of days in the last `n` where all 4Ps were done.
    private func countAll4PInLastNDays(_ n: Int) -> Int {
        lastNDateKeys(n).reduce(0) { acc, key in
            let s = perDayCompletedOrLive(key)
            return acc + ( (!s.isEmpty && dayHasAllFourPs(s)) ? 1 : 0 )
        }
    }

    /// Rolling count of days in the last `n` where a specific pillar flag appeared.
    private func countPillarInLastNDays(flag: String, n: Int) -> Int {
        lastNDateKeys(n).reduce(0) { acc, key in
            let s = perDayCompletedOrLive(key)
            return acc + ( s.contains(flag) ? 1 : 0 )
        }
    }
}

// MARK: - Compact list tweaks (reuse)
private struct CompactListTweaks: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .contentMargins(.vertical, 0)
                .listSectionSpacing(.compact)
                .listRowSpacing(0)
        } else { content }
    }
}
