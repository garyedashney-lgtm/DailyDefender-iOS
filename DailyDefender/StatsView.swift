import SwiftUI
import Foundation
import FirebaseFirestore

// MARK: - Footer navigation signal (match your FooterBar)
extension Notification.Name {
    /// Posted when the Footer "More" icon is tapped.
    static let moreTabTapped = Notification.Name("Footer.MoreTabTapped")
}

// MARK: - Shared models

struct TripleWindow: Equatable {
    let d7: Int
    let d30: Int
    let d60: Int
}

struct LeaderboardEntry: Identifiable, Equatable {
    let id = UUID()
    let displayName: String
    let total7: Int
    let total30: Int
    let total60: Int
}

struct SquadEntry: Identifiable, Equatable {
    let id = UUID()
    let squadLabel: String
    let total7: Int
    let total30: Int
    let total60: Int
}

enum LeaderboardSort {
    case d7, d30, d60
}

// MARK: - Stats View (iOS) — mirrors Android "All 4 Ps" stats + leaderboard

struct StatsView: View {
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    // UI
    @State private var showFourPs = false
    @State private var goProfileEdit = false

    // Leaderboard state
    @State private var leaderboardSort: LeaderboardSort = .d7
    @State private var leaderboardEntries: [LeaderboardEntry] = []
    @State private var leaderboardLoading = false
    @State private var leaderboardError: String?

    // Squad leaderboard state
    @State private var squadEntries: [SquadEntry] = []
    @State private var squadLoading = false
    @State private var squadError: String?

    // Theme helpers
    private var todayStringYMD: String {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }

    private var isPro: Bool {
        session.tier == .pro
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navy900.ignoresSafeArea()

                List {
                    // Header (centered) — background now matches page (navy)
                    Section {
                        VStack(spacing: 8) {
                            Text("Daily Defender Activity")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }
                    .listRowBackground(AppTheme.navy900)

                    // Activity table (with totals)
                    Section {
                        DailyDefenderActivityCard()
                            .environmentObject(store)
                            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(AppTheme.navy900)
                    }

                    // --- Pro-only Leaderboard (users + squads) ---
                    if isPro {
                        Section {
                            LeaderboardCard(
                                sort: $leaderboardSort,
                                entries: leaderboardEntries,
                                isLoading: leaderboardLoading,
                                errorText: leaderboardError
                            )
                            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(AppTheme.navy900)
                        }

                        Section {
                            SquadRankingsCard(
                                entries: squadEntries,
                                sort: leaderboardSort,
                                isLoading: squadLoading,
                                errorText: squadError
                            )
                            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(AppTheme.navy900)
                        }
                    }

                    // Extra spacer so you can scroll well past the last card
                    Section {
                        Color.clear
                            .frame(height: 100)   // ⬅️ bumped bottom padding
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.navy900)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .modifier(CompactListTweaks())
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true) // no back chevron
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
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
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
                    .onTapGesture { goProfileEdit = true }
                    .accessibilityLabel("Profile")
                }
            }
            .fullScreenCover(isPresented: $showFourPs) {
                ShieldPage(imageName: "four_ps")
            }
            NavigationLink("", isActive: $goProfileEdit) {
                ProfileEditView()
                    .environmentObject(store)
                    .environmentObject(session)
            }
            .hidden()

            // === Footer wiring: tapping "More" should pop to More screen ===
            .onReceive(NotificationCenter.default.publisher(for: .moreTabTapped)) { _ in
                dismiss()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("reselectTab"))) { note in
                if let page = note.object as? IosPage, page == .more {
                    dismiss()
                }
            }
            // Load / reload leaderboards when:
            // - view appears
            // - sort changes
            // - tier flips to/from pro
            .onAppear { loadLeaderboards() }
            .onChange(of: leaderboardSort) { _ in loadLeaderboards() }
            .onChange(of: session.tier) { _ in loadLeaderboards() }
        }
    }

    // MARK: - Firestore leaderboard loading (with local override for current user)

    private func loadLeaderboards() {
        // Only Pro users see/load leaderboard
        guard session.tier == .pro else {
            leaderboardEntries = []
            leaderboardError = nil
            leaderboardLoading = false

            squadEntries = []
            squadError = nil
            squadLoading = false
            return
        }

        leaderboardLoading = true
        squadLoading = true
        leaderboardError = nil
        squadError = nil

        Task {
            // 1) Compute local totals for current user (from device snapshots)
            let localTotals = await MainActor.run {
                self.computeLocalTotalsForCurrentUser()
            }
            let currentUid = await MainActor.run {
                self.session.user?.uid
            }

            do {
                let db = session.db
                let usersRef = db.collection("users")
                let squadsRef = db.collection("squads")

                // --- 2) Pull up to 500 Pro users ---
                let proSnapshot = try await usersRef
                    .whereField("tier", isEqualTo: "pro")
                    .limit(to: 500)
                    .getDocuments()

                let docs = proSnapshot.documents

                func totalsForDoc(_ doc: QueryDocumentSnapshot) -> (Int, Int, Int) {
                    let data = doc.data()

                    // For current user, override with live local totals
                    if let uid = currentUid, doc.documentID == uid {
                        return (localTotals.d7, localTotals.d30, localTotals.d60)
                    }

                    let t7  = data["total7"]  as? Int ?? (data["total7"]  as? NSNumber)?.intValue ?? 0
                    let t30 = data["total30"] as? Int ?? (data["total30"] as? NSNumber)?.intValue ?? 0
                    let t60 = data["total60"] as? Int ?? (data["total60"] as? NSNumber)?.intValue ?? 0
                    return (t7, t30, t60)
                }

                func docScore(_ doc: QueryDocumentSnapshot) -> Int {
                    let (t7, t30, t60) = totalsForDoc(doc)
                    switch leaderboardSort {
                    case .d7:  return t7
                    case .d30: return t30
                    case .d60: return t60
                    }
                }

                // --- 3) Top 5 Pro users ---
                let sortedDocs = docs.sorted { docScore($0) > docScore($1) }
                let topDocs = Array(sortedDocs.prefix(5))

                let topEntries: [LeaderboardEntry] = topDocs.compactMap { doc in
                    let data = doc.data()
                    let name = (data["displayName"] as? String)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        ?? (data["email"] as? String)
                        ?? ""

                    if name.isEmpty { return nil }

                    let (t7, t30, t60) = totalsForDoc(doc)

                    return LeaderboardEntry(
                        displayName: name,
                        total7: t7,
                        total30: t30,
                        total60: t60
                    )
                }

                await MainActor.run {
                    self.leaderboardEntries = topEntries
                }

                // --- 4) Start squad map from /squads (all squads show even at 0 pts) ---
                var squadMap: [String: SquadEntry] = [:]  // key = full squad name

                let squadsSnapshot = try await squadsRef.getDocuments()
                for sDoc in squadsSnapshot.documents {
                    let sData = sDoc.data()
                    let fullName = (sData["name"] as? String ?? sDoc.documentID)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if fullName.isEmpty { continue }

                    let displayLabel = squadDisplayLabel(fullName)
                    if squadMap[fullName] == nil {
                        squadMap[fullName] = SquadEntry(
                            squadLabel: displayLabel,
                            total7: 0,
                            total30: 0,
                            total60: 0
                        )
                    }
                }

                // --- 5) Aggregate Pro user totals into squads ---
                for doc in docs {
                    let data = doc.data()
                    let fullName = ((data["squadID"] as? String) ?? (data["squadId"] as? String) ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if fullName.isEmpty { continue }

                    let (t7, t30, t60) = totalsForDoc(doc)

                    if var existing = squadMap[fullName] {
                        existing = SquadEntry(
                            squadLabel: existing.squadLabel,
                            total7: existing.total7 + t7,
                            total30: existing.total30 + t30,
                            total60: existing.total60 + t60
                        )
                        squadMap[fullName] = existing
                    } else {
                        let displayLabel = squadDisplayLabel(fullName)
                        squadMap[fullName] = SquadEntry(
                            squadLabel: displayLabel,
                            total7: t7,
                            total30: t30,
                            total60: t60
                        )
                    }
                }

                // --- 6) Sort squads by selected window ---
                let sortedSquads: [SquadEntry] = squadMap.values.sorted { a, b in
                    let scoreA: Int
                    let scoreB: Int
                    switch leaderboardSort {
                    case .d7:
                        scoreA = a.total7
                        scoreB = b.total7
                    case .d30:
                        scoreA = a.total30
                        scoreB = b.total30
                    case .d60:
                        scoreA = a.total60
                        scoreB = b.total60
                    }
                    return scoreA > scoreB
                }

                await MainActor.run {
                    self.squadEntries = sortedSquads
                    self.leaderboardLoading = false
                    self.squadLoading = false
                }
            } catch {
                let msg = error.localizedDescription

                await MainActor.run {
                    self.leaderboardError = msg
                    self.leaderboardEntries = []
                    self.leaderboardLoading = false

                    self.squadError = msg
                    self.squadEntries = []
                    self.squadLoading = false
                }
            }
        }
    }

    // MARK: - Local totals for current user (mirrors DailyDefenderActivityCard.totalsRow)

    private func computeLocalTotalsForCurrentUser() -> TripleWindow {
        let physId = "pillar_phys"
        let pietyId = "pillar_piety"
        let peopleId = "pillar_people"
        let prodId = "pillar_prod"

        func lastNDateKeys(_ n: Int) -> [String] {
            let cal = Calendar(identifier: .gregorian)
            let df = DateFormatter()
            df.calendar = cal
            df.dateFormat = "yyyyMMdd"
            return (0..<n).compactMap { i in
                guard let d = cal.date(byAdding: .day, value: -i, to: Date()) else { return nil }
                return df.string(from: d)
            }
        }

        func todayKey() -> String {
            let df = DateFormatter()
            df.calendar = Calendar(identifier: .gregorian)
            df.dateFormat = "yyyyMMdd"
            return df.string(from: Date())
        }

        func perDayCompletedOrLive(_ dateKey: String) -> Set<String> {
            if let snap = UserDefaults.standard.array(forKey: "daily_completed_\(dateKey)") as? [String] {
                return Set(snap)
            }
            if dateKey == todayKey() {
                return store.completed
            }
            return []
        }

        func dayHasAllFourPs(_ perDay: Set<String>) -> Bool {
            perDay.contains(physId) &&
            perDay.contains(pietyId) &&
            perDay.contains(peopleId) &&
            perDay.contains(prodId)
        }

        func countAll4PInLastNDays(_ n: Int) -> Int {
            lastNDateKeys(n).reduce(0) { acc, key in
                let s = perDayCompletedOrLive(key)
                return acc + ( (!s.isEmpty && dayHasAllFourPs(s)) ? 1 : 0 )
            }
        }

        func countPillarInLastNDays(flag: String, n: Int) -> Int {
            lastNDateKeys(n).reduce(0) { acc, key in
                let s = perDayCompletedOrLive(key)
                return acc + ( s.contains(flag) ? 1 : 0 )
            }
        }

        // Same as totalsRow in DailyDefenderActivityCard
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

        return TripleWindow(d7: total7, d30: total30, d60: total60)
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

            // Data rows
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
        return (0..<n).compactMap { i in
            guard let d = cal.date(byAdding: .day, value: -i, to: Date()) else { return nil }
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

// MARK: - Leaderboard Card (users)

private struct LeaderboardCard: View {
    @Binding var sort: LeaderboardSort
    let entries: [LeaderboardEntry]
    let isLoading: Bool
    let errorText: String?

    private let colWidth: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title
            HStack {
                Spacer()
                Text("Leaderboard")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }
            .padding(.bottom, 4)

            // Sort chips — centered with extra padding below
            VStack(spacing: 4) {
                HStack(spacing: 12) {
                    Text("Sort by:")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary.opacity(0.9))

                    HStack(spacing: 8) {
                        LeaderboardSortChip(label: "7 Day", selected: sort == .d7) {
                            sort = .d7
                        }
                        LeaderboardSortChip(label: "30 Day", selected: sort == .d30) {
                            sort = .d30
                        }
                        LeaderboardSortChip(label: "60 Day", selected: sort == .d60) {
                            sort = .d60
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.bottom, 10)

            // Header row
            HStack {
                Text("#")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 24, alignment: .leading)
                Text("User")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("7 Day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: colWidth, alignment: .trailing)
                Text("30 Day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: colWidth, alignment: .trailing)
                Text("60 Day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: colWidth, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            // Card surface
            VStack(spacing: 6) {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                } else if let e = errorText {
                    Text(e)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else if entries.isEmpty {
                    Text("No leaderboard data yet.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(entries.enumerated()), id: \.1.id) { (index, entry) in
                        LeaderboardRow(rank: index + 1, entry: entry, colWidth: colWidth)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.surfaceUI)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

private struct LeaderboardRow: View {
    let rank: Int
    let entry: LeaderboardEntry
    let colWidth: CGFloat

    var body: some View {
        HStack {
            Text("\(rank)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 24, alignment: .leading)

            Text(shortenName(entry.displayName))
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(entry.total7)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: colWidth, alignment: .trailing)

            Text("\(entry.total30)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: colWidth, alignment: .trailing)

            Text("\(entry.total60)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: colWidth, alignment: .trailing)
        }
    }
}

// MARK: - Squad Rankings Card

private struct SquadRankingsCard: View {
    let entries: [SquadEntry]
    let sort: LeaderboardSort
    let isLoading: Bool
    let errorText: String?

    private let colWidth: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title
            HStack {
                Spacer()
                Text("Squad Rankings")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }
            .padding(.bottom, 4)

            // Header row
            HStack {
                Text("#")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 24, alignment: .leading)
                Text("Squad")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("7 Day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: colWidth, alignment: .trailing)
                Text("30 Day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: colWidth, alignment: .trailing)
                Text("60 Day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: colWidth, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            VStack(spacing: 6) {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                } else if let e = errorText {
                    Text(e)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else if entries.isEmpty {
                    Text("No squad data yet.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(entries.enumerated()), id: \.1.id) { (index, entry) in
                        SquadRow(rank: index + 1, entry: entry, colWidth: colWidth)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.surfaceUI)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }
}

private struct SquadRow: View {
    let rank: Int
    let entry: SquadEntry
    let colWidth: CGFloat

    var body: some View {
        HStack {
            Text("\(rank)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 24, alignment: .leading)

            Text(entry.squadLabel)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(entry.total7)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: colWidth, alignment: .trailing)

            Text("\(entry.total30)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: colWidth, alignment: .trailing)

            Text("\(entry.total60)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: colWidth, alignment: .trailing)
        }
    }
}

// MARK: - Helper UI bits

private struct LeaderboardSortChip: View {
    let label: String
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.footnote)
                .fontWeight(selected ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 999)
                        .strokeBorder(
                            selected ? AppTheme.appGreen : AppTheme.textSecondary.opacity(0.45),
                            lineWidth: 1
                        )
                )
                .foregroundStyle(selected ? AppTheme.appGreen : AppTheme.textPrimary.opacity(0.9))
        }
        .buttonStyle(.plain)
    }
}

private func shortenName(_ full: String?) -> String {
    guard let full,
          !full.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return "User"
    }
    let parts = full.split(whereSeparator: { $0.isWhitespace })
    if parts.count >= 2 {
        return "\(parts[0]) \(parts[1].first.map(String.init) ?? "")."
    } else {
        return String(parts[0])
    }
}

// Convert full squad name like "Matinee Monsters" → "Monsters"
private func squadDisplayLabel(_ full: String) -> String {
    let trimmed = full.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return trimmed }
    let parts = trimmed.split(whereSeparator: { $0.isWhitespace })
    return parts.count >= 2 ? String(parts.last!) : trimmed
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
        } else {
            content
        }
    }
}
