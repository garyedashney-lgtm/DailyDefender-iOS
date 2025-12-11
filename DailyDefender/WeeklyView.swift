import SwiftUI
import UIKit

// MARK: - WeeklyView (bulleted, WCS snapshot to Journal)
struct WeeklyView: View {
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var session: SessionViewModel

    // MARK: Week key (ISO Monday-start)
    private var weekKey: String { Self.isoWeekKey(for: Date()) }
    private static func isoWeekKey(for date: Date) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2 // Monday
        let y = cal.component(.yearForWeekOfYear, from: date)
        let w = cal.component(.weekOfYear, from: date)
        return String(format: "%04d-W%02d", y, w)
    }

    // MARK: Weekly Totals (display only, rolling last 7 days)
    private let weeklyTotalCap = 28       // 4 pillars * 7 days
    private let perPillarCap = 7          // each P max once/day for 7 days

    private func pid(_ p: Pillar) -> String {
        switch p {
        case .Physiology: return "pillar_phys"
        case .Piety:      return "pillar_piety"
        case .People:     return "pillar_people"
        case .Production: return "pillar_prod"
        }
    }

    // Rolling 7-day counts pulled from daily snapshots (Stats parity)
    private var physCount: Int {
        min(countPillarInLast7Days(flag: pid(.Physiology)), perPillarCap)
    }
    private var pietyCount: Int {
        min(countPillarInLast7Days(flag: pid(.Piety)), perPillarCap)
    }
    private var peopleCount: Int {
        min(countPillarInLast7Days(flag: pid(.People)), perPillarCap)
    }
    private var prodCount: Int {
        min(countPillarInLast7Days(flag: pid(.Production)), perPillarCap)
    }

    private var displayCoreTotal: Int {
        min(physCount + pietyCount + peopleCount + prodCount, weeklyTotalCap)
    }
    private var weeklyProgress: Double {
        weeklyTotalCap == 0 ? 0 : Double(displayCoreTotal) / Double(weeklyTotalCap)
    }

    // MARK: Weekly text (persisted per week)
    @State private var winsLosses: String = ""
    @State private var phys: String = ""
    @State private var prayer: String = ""
    @State private var people: String = ""
    @State private var production: String = ""
    @State private var carryText: String = ""
    @State private var carryDone: Bool = false
    @State private var oneThingNextWeek: String = ""
    @State private var journalNotes: String = ""

    // UI
    @State private var showShield = false
    @State private var goProfileEdit = false
    @State private var didHydrateOnce = false
    @State private var showSavedAlert = false

    // Focus state for auto-scrolling & headroom
    @State private var anyEditorFocused = false
    @State private var focusedAnchor: String? = nil

    // Debounced save
    @State private var saveWork: DispatchWorkItem?
    private func scheduleSave() {
        saveWork?.cancel()
        let w = DispatchWorkItem { self.flushAll() }
        saveWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: w)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack {
                    AppTheme.navy900.ignoresSafeArea()

                    List {
                        // === Progress strip ===
                        Section {
                            VStack(spacing: 8) {
                                ProgressView(value: weeklyProgress)
                                    .tint(AppTheme.appGreen)
                                Text("\(displayCoreTotal) / \(weeklyTotalCap) completed this week")
                                    .frame(maxWidth: .infinity)
                                    .multilineTextAlignment(.center)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
                        }
                        .listRowBackground(AppTheme.surface)

                        // === Wins / Losses ===
                        weeklySection(
                            anchorId: "wins",
                            title: "Wins / Losses",
                            countText: nil,
                            subtitle: "",
                            text: $winsLosses,
                            placeholder: "  type your notes here…",
                            onFocus: { focused in
                                anyEditorFocused = focused
                                if focused { scrollTo("wins", proxy: proxy) }
                            }
                        )

                        // === Physiology ===
                        weeklySection(
                            anchorId: "phys",
                            title: "Physiology",
                            countText: "\(physCount)/\(perPillarCap)",
                            subtitle: "   The body is the universal address of your existence",
                            text: $phys,
                            placeholder: "  type your notes here…",
                            onFocus: { f in
                                anyEditorFocused = f
                                if f { scrollTo("phys", proxy: proxy) }
                            }
                        )

                        // === Piety ===
                        weeklySection(
                            anchorId: "piety",
                            title: "Piety",
                            countText: "\(pietyCount)/\(perPillarCap)",
                            subtitle: "   Using mystery & awe as the spirit speaks for the soul",
                            text: $prayer,
                            placeholder: "  type your notes here…",
                            onFocus: { f in
                                anyEditorFocused = f
                                if f { scrollTo("piety", proxy: proxy) }
                            }
                        )

                        // === People ===
                        weeklySection(
                            anchorId: "people",
                            title: "People",
                            countText: "\(peopleCount)/\(perPillarCap)",
                            subtitle: "   Team Human: herd animals who exist in each other",
                            text: $people,
                            placeholder: "  type your notes here…",
                            onFocus: { f in
                                anyEditorFocused = f
                                if f { scrollTo("people", proxy: proxy) }
                            }
                        )

                        // === Production ===
                        weeklySection(
                            anchorId: "prod",
                            title: "Production",
                            countText: "\(prodCount)/\(perPillarCap)",
                            subtitle: "   A man produces more than he consumes",
                            text: $production,
                            placeholder: "  type your notes here…",
                            onFocus: { f in
                                anyEditorFocused = f
                                if f { scrollTo("prod", proxy: proxy) }
                            }
                        )

                        // === 🎯 Carryover Done? ===
                        weeklyCarryoverSection(
                            anchorId: "carry",
                            leadingEmoji: "🎯",
                            title: "This Week’s One Thing Done?",
                            text: $carryText,
                            isDone: $carryDone,
                            placeholder: "  — none set last week —",
                            onFocus: { f in
                                anyEditorFocused = f
                                if f { scrollTo("carry", proxy: proxy) }
                            }
                        )

                        // === 🎯 One Thing Next Week ===
                        weeklySimpleSection(
                            anchorId: "next",
                            leadingEmoji: "🎯",
                            title: "One Thing for Next Week",
                            subtitle: "",
                            text: $oneThingNextWeek,
                            placeholder: "  type your notes here…",
                            onFocus: { f in
                                anyEditorFocused = f
                                if f { scrollTo("next", proxy: proxy) }
                            }
                        )

                        // === 📓 Extra Notes ===
                        weeklySimpleSection(
                            anchorId: "notes",
                            leadingEmoji: "📓",
                            title: "Extra Notes",
                            subtitle: "",
                            text: $journalNotes,
                            placeholder: "  type your extra notes here…",
                            onFocus: { f in
                                anyEditorFocused = f
                                if f { scrollTo("notes", proxy: proxy) }
                            }
                        )

                        // === Share / Save to Journal row ===
                        Section {
                            HStack(spacing: 12) {
                                // SHARE BUTTON — available to all tiers
                                Button(action: shareWeeklySummary) {
                                    Text("Share")
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                .background(AppTheme.navy900)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppTheme.textPrimary.opacity(0.35), lineWidth: 1)
                                )

                                Spacer(minLength: 12)

                                // SAVE TO JOURNAL (WCS snapshot) — Pro only
                                if session.tier.canAccessJournal {
                                    Button(action: { saveWeeklySnapshotToJournal() }) {
                                        Text("Save to Journal")
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(AppTheme.appGreen)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Save Weekly Check-In snapshot to Journal Library")
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.navy900)

                        // Bottom spacer so the last section isn't cramped
                        Section { Color.clear.frame(height: 56) }
                            .listRowSeparator(.hidden)
                            .listRowBackground(AppTheme.navy900)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .modifier(CompactListTweaks())
                }
                .withKeyboardDismiss()
                // Fixed headroom when an editor is focused (no keyboard math)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: anyEditorFocused ? 96 : 48)
                }
            }

            // Toolbar
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showShield = true }) {
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
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        HStack(spacing: 8) {
                            Text("📅")
                            Text("Weekly Check-In")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        Text("Scoring: last 7 days")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Notes: reset weekly (Sun night)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.bottom, 6)
                    }
                }
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.navy900, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)

            // Shield
            .fullScreenCover(isPresented: $showShield) { ShieldPage(imageName: "four_ps") }

            // Hydrate + save
            .task {
                if !didHydrateOnce {
                    hydrateFromStorage()
                    didHydrateOnce = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                flushAll()
            }

            // Debounced persistence on change
            .onChange(of: winsLosses)       { _ in scheduleSave() }
            .onChange(of: phys)             { _ in scheduleSave() }
            .onChange(of: prayer)           { _ in scheduleSave() }
            .onChange(of: people)           { _ in scheduleSave() }
            .onChange(of: production)       { _ in scheduleSave() }
            .onChange(of: carryText)        { _ in scheduleSave() }
            .onChange(of: carryDone)        { _ in scheduleSave() }
            .onChange(of: oneThingNextWeek) { _ in scheduleSave() }
            .onChange(of: journalNotes)     { _ in scheduleSave() }

            NavigationLink("", isActive: $goProfileEdit) {
                ProfileEditView()
                    .environmentObject(store)
                    .environmentObject(session)
            }.hidden()

            .alert("Saved to Journal ✅", isPresented: $showSavedAlert) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    // Smooth scroll helper
    private func scrollTo(_ id: String, proxy: ScrollViewProxy) {
        focusedAnchor = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: 0.18)) {
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
    }

    // MARK: Sections
    @ViewBuilder
    private func weeklySection(
        anchorId: String,
        title: String,
        countText: String?,
        subtitle: String,
        text: Binding<String>,
        placeholder: String,
        onFocus: @escaping (Bool) -> Void
    ) -> some View {
        Section {
            HStack(spacing: 8) {
                SectionHeader(label: title, pillar: pillarForTitle(title), countText: nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(AppTheme.navy900)
            .overlay(alignment: .trailing) {
                if let count = countText {
                    Text(count)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.trailing, 4)
                }
            }

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption.italic())
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.navy900)
            }

            BulletNotesCard(
                text: text,
                placeholder: placeholder,
                onFocusChange: onFocus
            )
            .listRowInsets(.init(top: 0, leading: 0, bottom: 6, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(AppTheme.navy900)
            .id(anchorId)
        }
    }

    @ViewBuilder
    private func weeklySimpleSection(
        anchorId: String,
        leadingEmoji: String? = nil,
        title: String,
        subtitle: String,
        text: Binding<String>,
        placeholder: String,
        onFocus: @escaping (Bool) -> Void
    ) -> some View {
        Section {
            OneLineHeaderRow(leadingEmoji: leadingEmoji, title: title)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.navy900)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption.italic())
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.navy900)
            }

            BulletNotesCard(
                text: text,
                placeholder: placeholder,
                onFocusChange: onFocus
            )
            .listRowInsets(.init(top: 0, leading: 0, bottom: 6, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(AppTheme.navy900)
            .id(anchorId)
        }
    }

    @ViewBuilder
    private func weeklyCarryoverSection(
        anchorId: String,
        leadingEmoji: String? = nil,
        title: String,
        text: Binding<String>,
        isDone: Binding<Bool>,
        placeholder: String,
        onFocus: @escaping (Bool) -> Void
    ) -> some View {
        Section {
            HStack(spacing: 8) {
                if let emoji = leadingEmoji { Text(emoji).font(.title3) }
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
                let canMark = !text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                CheckSquare(
                    checked: isDone.wrappedValue && canMark,
                    onTap: {
                        if canMark {
                            isDone.wrappedValue.toggle()
                            saveCarryoverDone(isDone.wrappedValue)
                            scheduleSave()
                        }
                    }
                )
                .opacity(canMark ? 1 : 0.5)
                .padding(.trailing, 8)
            }
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(AppTheme.navy900)

            BulletNotesCard(
                text: text,
                placeholder: placeholder,
                onFocusChange: onFocus
            )
            .listRowInsets(.init(top: 0, leading: 0, bottom: 6, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(AppTheme.navy900)
            .id(anchorId)
        }
    }

    private func pillarForTitle(_ title: String) -> Pillar {
        switch title.lowercased() {
        case "physiology": return .Physiology
        case "piety": return .Piety
        case "people": return .People
        case "production": return .Production
        default: return .Physiology
        }
    }

    // MARK: Persistence (scoped by week) — journal text only
    private func key(_ base: String) -> String { "\(base)_\(weekKey)" }

    private func hydrateFromStorage() {
        let d = UserDefaults.standard
        winsLosses       = d.string(forKey: key("weekly_winsLosses")) ?? ""
        phys             = d.string(forKey: key("weekly_phys")) ?? ""
        prayer           = d.string(forKey: key("weekly_prayer")) ?? ""
        people           = d.string(forKey: key("weekly_people")) ?? ""
        production       = d.string(forKey: key("weekly_production")) ?? ""
        carryText        = d.string(forKey: key("weekly_carryText")) ?? ""
        carryDone        = d.bool(forKey:  key("weekly_carryDone"))
        oneThingNextWeek = d.string(forKey: key("weekly_oneThingNextWeek")) ?? ""
        journalNotes     = d.string(forKey: key("weekly_journalNotes")) ?? ""
    }

    private func flushAll() {
        let d = UserDefaults.standard
        d.set(winsLosses,       forKey: key("weekly_winsLosses"))
        d.set(phys,             forKey: key("weekly_phys"))
        d.set(prayer,           forKey: key("weekly_prayer"))
        d.set(people,           forKey: key("weekly_people"))
        d.set(production,       forKey: key("weekly_production"))
        d.set(carryText,        forKey: key("weekly_carryText"))
        d.set(carryDone,        forKey: key("weekly_carryDone"))
        d.set(oneThingNextWeek, forKey: key("weekly_oneThingNextWeek"))
        d.set(journalNotes,     forKey: key("weekly_journalNotes"))
    }

    private func saveCarryoverDone(_ v: Bool) {
        UserDefaults.standard.set(v, forKey: key("weekly_carryDone"))
    }

    private func clearAll() {
        winsLosses = ""
        phys = ""
        prayer = ""
        people = ""
        production = ""
        carryText = ""
        carryDone = false
        oneThingNextWeek = ""
        journalNotes = ""
        flushAll()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: Share (no filler lines)
    private func shareWeeklySummary() {
        func keepUserLines(_ s: String) -> String { s }

        let text = """
        **Weekly Check-In (\(weekKey))**
        Core Points: \(displayCoreTotal)/\(weeklyTotalCap)
        🏋 Physiology: \(physCount)/\(perPillarCap)
        🙏 Piety: \(pietyCount)/\(perPillarCap)
        👥 People: \(peopleCount)/\(perPillarCap)
        💼 Production: \(prodCount)/\(perPillarCap)

        **⚖️ Wins / Losses:**
        \(keepUserLines(winsLosses))

        **🏋 Physiology Notes:**
        \(keepUserLines(phys))

        **🙏 Piety Notes:**
        \(keepUserLines(prayer))

        **👥 People Notes:**
        \(keepUserLines(people))

        **💼 Production Notes:**
        \(keepUserLines(production))

        **🎯 This Week’s One Thing: \(carryDone ? "DONE!" : "NOT DONE")**
        \(keepUserLines(carryText))

        **🎯 One Thing Next Week:**
        \(keepUserLines(oneThingNextWeek))

        **📓 Extra Notes:**
        \(keepUserLines(journalNotes))
        """
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.firstKeyWindow?.rootViewController?.present(av, animated: true)
    }

    // MARK: - Save Weekly snapshot to Journal (WCS, read-only)
    private func saveWeeklySnapshotToJournal() {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let stamp = formatter.string(from: now)

        func block(_ header: String, _ text: String) -> String {
            let cleaned = text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { "- \($0)" }
                .joined(separator: "\n")

            return cleaned.isEmpty ? "\(header)\n" : "\(header)\n\(cleaned)\n"
        }

        let carryStatus = carryDone ? "DONE!" : "NOT DONE"

        let body = [
            "📅 Weekly Check-In Snapshot (\(stamp))",
            "Week: \(weekKey)",
            "Core Points: \(displayCoreTotal)/\(weeklyTotalCap)",
            "🏋 Physiology: \(physCount)/\(perPillarCap)",
            "🙏 Piety: \(pietyCount)/\(perPillarCap)",
            "👥 People: \(peopleCount)/\(perPillarCap)",
            "💼 Production: \(prodCount)/\(perPillarCap)",
            "",
            block("⚖️ Wins / Losses", winsLosses),
            block("🏋 Physiology Notes", phys),
            block("🙏 Piety Notes", prayer),
            block("👥 People Notes", people),
            block("💼 Production Notes", production),
            block("🎯 This Week’s One Thing (\(carryStatus))", carryText),
            block("🎯 One Thing Next Week", oneThingNextWeek),
            block("📓 Extra Notes", journalNotes)
        ]
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)

        JournalMemoryStore.shared.addFreeFlow(
            title: "WCS: Weekly Check-In Snapshot: \(weekKey)",
            body: body,
            createdAt: now
        )

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showSavedAlert = true
    }

    // MARK: - Rolling 7-day logic (shared with StatsView conceptually)

    private func last7DateKeys() -> [String] {
        let cal = Calendar(identifier: .gregorian)
        let df = DateFormatter()
        df.calendar = cal
        df.dateFormat = "yyyyMMdd"
        return (0..<7).compactMap { i in
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

    /// Rolling count of days in the last 7 where a specific pillar flag appeared.
    private func countPillarInLast7Days(flag: String) -> Int {
        last7DateKeys().reduce(0) { acc, key in
            let s = perDayCompletedOrLive(key)
            return acc + (s.contains(flag) ? 1 : 0)
        }
    }
}

// MARK: - One-line header
private struct OneLineHeaderRow<Trailing: View>: View {
    let leadingEmoji: String?
    let title: String
    var trailingWidth: CGFloat? = nil
    @ViewBuilder var trailing: () -> Trailing

    init(leadingEmoji: String? = nil, title: String, trailingWidth: CGFloat? = nil, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.leadingEmoji = leadingEmoji
        self.title = title
        self.trailingWidth = trailingWidth
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 8) {
            if let emoji = leadingEmoji { Text(emoji).font(.title3) }
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 6)
                .frame(height: 1)
                .overlay(Rectangle().fill(AppTheme.divider))
            if let w = trailingWidth { trailing().frame(width: w, alignment: .trailing) } else { trailing() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 0)
    }
}

// MARK: - Notes card (auto-grow + bullet column)
private struct BulletNotesCard: View {
    @Binding var text: String
    let placeholder: String
    var onFocusChange: ((Bool) -> Void)? = nil

    @State private var measuredHeight: CGFloat = 46
    @State private var isFocused: Bool = false

    init(text: Binding<String>, placeholder: String, onFocusChange: ((Bool) -> Void)? = nil) {
        _text = text
        self.placeholder = placeholder
        self.onFocusChange = onFocusChange
    }

    private var lineCount: Int {
        max(text.split(separator: "\n", omittingEmptySubsequences: false).count, 1)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surfaceUI)

            // Placeholder only when not focused AND no text
            if !isFocused && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .font(.callout.italic())
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }

            HStack(alignment: .top, spacing: 8) {
                // Bullet column (logical lines, not wraps)
                VStack(alignment: .trailing, spacing: 4) {
                    ForEach(0..<lineCount, id: \.self) { _ in
                        Text("•")
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(height: 18, alignment: .top)
                    }
                }
                .padding(.top, 10)
                .padding(.leading, 8)

                WeeklyAutoGrowTextView(
                    text: $text,
                    onHeightChange: { h in
                        let clamped = max(46, ceil(h))
                        if abs(clamped - measuredHeight) > 0.5 {
                            measuredHeight = clamped
                        }
                    },
                    onFocusChange: { focused in
                        // Track focus locally so we can hide/show placeholder immediately
                        isFocused = focused
                        // Still bubble the focus change up to WeeklyView
                        onFocusChange?(focused)
                    }
                )
                .frame(height: measuredHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 8)
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 0)
        .padding(.bottom, 4)
    }
}
// MARK: - UITextView wrapper (auto-grow, sentences, no bullets in text)
private struct WeeklyAutoGrowTextView: UIViewRepresentable {
    @Binding var text: String
    var onHeightChange: (CGFloat) -> Void
    var onFocusChange: ((Bool) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.textColor = UIColor.white
        tv.tintColor = UIColor(AppTheme.appGreen)
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.isScrollEnabled = false
        tv.keyboardDismissMode = .interactive
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        tv.textContainer.widthTracksTextView = true
        tv.textContainer.lineBreakMode = .byWordWrapping
        tv.autocorrectionType = .yes
        tv.autocapitalizationType = .sentences
        tv.smartDashesType = .no
        tv.smartQuotesType = .no
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tv.delegate = context.coordinator
        tv.text = text

        DispatchQueue.main.async { self.remeasure(tv) }
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        DispatchQueue.main.async { self.remeasure(uiView) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: WeeklyAutoGrowTextView
        init(_ parent: WeeklyAutoGrowTextView) { self.parent = parent }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onFocusChange?(true)
            parent.remeasure(textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onFocusChange?(false)
            parent.remeasure(textView)
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
            parent.remeasure(textView)
        }
    }

    fileprivate func remeasure(_ tv: UITextView) {
        var targetWidth = tv.bounds.width
        if targetWidth <= 0 {
            // leave room for bullets + padding
            targetWidth = UIScreen.main.bounds.width - 32 - 20
        }
        let size = tv.sizeThatFits(CGSize(width: targetWidth, height: .greatestFiniteMagnitude))
        onHeightChange(size.height)
    }
}

// MARK: - CheckSquare (matches Daily-ish)
private struct CheckSquare: View {
    let checked: Bool
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            Image(systemName: checked ? "checkmark.square.fill" : "square")
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    checked ? .white : AppTheme.textPrimary,
                    checked ? AppTheme.appGreen : .clear
                )
                .font(.title3)
                .padding(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact list tweaks
private struct CompactListTweaks: ViewModifier {
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

// MARK: - Helpers
private extension UIApplication {
    var firstKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

private extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
