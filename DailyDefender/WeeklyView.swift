import SwiftUI
import UIKit

// MARK: - WeeklyView (Daily-style input; bullets removed)
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

    // MARK: Weekly Totals (display only)
    private let weeklyTotalCap = 28
    private let perPillarCap = 7

    @State private var coreTotalSaved: Int = 0
    @State private var pillarSaved: (phys: Int, piety: Int, people: Int, prod: Int) = (0,0,0,0)

    private func pid(_ p: Pillar) -> String {
        switch p {
        case .Physiology: return "pillar_phys"
        case .Piety:      return "pillar_piety"
        case .People:     return "pillar_people"
        case .Production: return "pillar_prod"
        }
    }
    private var todayCompletedPillarCount: Int {
        [Pillar.Physiology, .Piety, .People, .Production]
            .map { store.completed.contains(pid($0)) ? 1 : 0 }
            .reduce(0, +)
    }
    private var displayCoreTotal: Int {
        min(coreTotalSaved + todayCompletedPillarCount, weeklyTotalCap)
    }
    private var weeklyProgress: Double {
        weeklyTotalCap == 0 ? 0 : Double(displayCoreTotal) / Double(weeklyTotalCap)
    }
    private var physCount: Int   { min(pillarSaved.phys   + (store.completed.contains(pid(.Physiology)) ? 1 : 0), perPillarCap) }
    private var pietyCount: Int  { min(pillarSaved.piety  + (store.completed.contains(pid(.Piety)) ? 1 : 0), perPillarCap) }
    private var peopleCount: Int { min(pillarSaved.people + (store.completed.contains(pid(.People)) ? 1 : 0), perPillarCap) }
    private var prodCount: Int   { min(pillarSaved.prod   + (store.completed.contains(pid(.Production)) ? 1 : 0), perPillarCap) }

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
    @State private var showClearAlert = false
    @State private var didHydrateOnce = false

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

    var body: some View {
        if !session.isPro {
            PaywallCardView(title: "Pro Feature")
        } else {
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
                                placeholder: "type your notes here…",
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
                                placeholder: "type your notes here…",
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
                                placeholder: "type your notes here…",
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
                                placeholder: "type your notes here…",
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
                                placeholder: "type your notes here…",
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
                                placeholder: "— none set last week —",
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
                                placeholder: "type your notes here…",
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
                                placeholder: "type your extra notes here…",
                                onFocus: { f in
                                    anyEditorFocused = f
                                    if f { scrollTo("notes", proxy: proxy) }
                                }
                            )

                            // === Clear / Share row ===
                            Section {
                                HStack(spacing: 12) {
                                    Button(action: { showClearAlert = true }) {
                                        Text("Clear All")
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
                            Text("Week: \(weekKey)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textPrimary)
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
                .alert("Clear all weekly notes?", isPresented: $showClearAlert) {
                    Button("Clear All", role: .destructive) { clearAll() }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will remove all text in Weekly for week \(weekKey).")
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

    // MARK: Persistence (scoped by week)
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
        coreTotalSaved   = d.integer(forKey: key("weekly_coreTotalSaved"))
        pillarSaved = (
            d.integer(forKey: key("weekly_pSaved_phys")),
            d.integer(forKey: key("weekly_pSaved_piety")),
            d.integer(forKey: key("weekly_pSaved_people")),
            d.integer(forKey: key("weekly_pSaved_prod"))
        )
    }

    private func flushAll() {
        let d = UserDefaults.standard
        d.set(winsLosses, forKey: key("weekly_winsLosses"))
        d.set(phys, forKey: key("weekly_phys"))
        d.set(prayer, forKey: key("weekly_prayer"))
        d.set(people, forKey: key("weekly_people"))
        d.set(production, forKey: key("weekly_production"))
        d.set(carryText, forKey: key("weekly_carryText"))
        d.set(carryDone, forKey: key("weekly_carryDone"))
        d.set(oneThingNextWeek, forKey: key("weekly_oneThingNextWeek"))
        d.set(journalNotes, forKey: key("weekly_journalNotes"))
        d.set(coreTotalSaved, forKey: key("weekly_coreTotalSaved"))
        d.set(pillarSaved.phys,   forKey: key("weekly_pSaved_phys"))
        d.set(pillarSaved.piety,  forKey: key("weekly_pSaved_piety"))
        d.set(pillarSaved.people, forKey: key("weekly_pSaved_people"))
        d.set(pillarSaved.prod,   forKey: key("weekly_pSaved_prod"))
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

// MARK: - Notes card (auto-grow + wrap)
private struct BulletNotesCard: View { // name kept to avoid other ref changes
    @Binding var text: String
    let placeholder: String
    var onFocusChange: ((Bool) -> Void)? = nil
    @State private var measuredHeight: CGFloat = 46

    init(text: Binding<String>, placeholder: String, onFocusChange: ((Bool) -> Void)? = nil) {
        _text = text
        self.placeholder = placeholder
        self.onFocusChange = onFocusChange
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surfaceUI)

            BulletTextViewSimple(
                text: $text,
                placeholder: placeholder,
                onHeightChange: { h in
                    let clamped = max(46, ceil(h))
                    if abs(clamped - measuredHeight) > 0.5 { measuredHeight = clamped }
                },
                onFocusChange: onFocusChange
            )
            .frame(height: measuredHeight)
            .background(Color.clear)
        }
        .padding(.horizontal, 0)
        .padding(.bottom, 4)
    }
}

// MARK: - UITextView wrapper — paragraph spacing on Return, bullets removed
private struct BulletTextViewSimple: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
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
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        tv.textContainer.widthTracksTextView = true
        tv.textContainer.lineBreakMode = .byWordWrapping
        tv.contentInset = .zero
        tv.autocorrectionType = .yes
        tv.autocapitalizationType = .sentences
        tv.smartDashesType = .no
        tv.smartQuotesType = .no
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tv.delegate = context.coordinator

        // Placeholder label
        let label = UILabel()
        label.text = placeholder.lowercased()
        label.textColor = UIColor.white.withAlphaComponent(0.35)
        label.font = tv.font
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        tv.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: tv.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(lessThanOrEqualTo: tv.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: tv.topAnchor, constant: 10)
        ])
        context.coordinator.placeholderLabel = label

        tv.text = text
        label.isHidden = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        DispatchQueue.main.async { self.remeasure(tv) }
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        context.coordinator.placeholderLabel?.isHidden =
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        DispatchQueue.main.async { self.remeasure(uiView) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: BulletTextViewSimple
        weak var placeholderLabel: UILabel?

        init(_ parent: BulletTextViewSimple) { self.parent = parent }

        func textViewDidBeginEditing(_ textView: UITextView) {
            // Focus only
            placeholderLabel?.isHidden = true
            parent.onFocusChange?(true)
            parent.remeasure(textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            let trimmed = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
            placeholderLabel?.isHidden = !trimmed.isEmpty
            parent.onFocusChange?(false)
            parent.remeasure(textView)
        }

        func textView(_ textView: UITextView,
                      shouldChangeTextIn range: NSRange,
                      replacementText repl: String) -> Bool {
            // Paragraph spacing: convert single Return into blank-line Return
            if repl == "\n" {
                let ns = textView.text as NSString? ?? ""
                let replaced = ns.replacingCharacters(in: range, with: "\n\n")
                textView.text = replaced
                textView.selectedRange = NSRange(location: range.location + 2, length: 0)
                parent.text = replaced
                placeholderLabel?.isHidden = true
                parent.remeasure(textView)
                return false
            }
            return true
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
            let trimmed = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
            placeholderLabel?.isHidden = !trimmed.isEmpty
            parent.remeasure(textView)
        }
    }

    fileprivate func remeasure(_ tv: UITextView) {
        var targetWidth = tv.bounds.width
        if targetWidth <= 0 {
            targetWidth = UIScreen.main.bounds.width - 32
        }
        let size = tv.sizeThatFits(CGSize(width: targetWidth, height: .greatestFiniteMagnitude))
        onHeightChange(size.height)
    }
}

// MARK: - CheckSquare (matches Daily)
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

private func pillarSubtitle(forLabel label: String) -> String {
    switch label.lowercased() {
    case "physiology":
        return "The body is the universal address of your existence"
    case "piety":
        return "Using mystery & awe as the spirit speaks for the soul"
    case "people":
        return "Team Human: herd animals who exist in each other"
    case "production":
        return "A man produces more than he consumes"
    default:
        return ""
    }
}

private extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
