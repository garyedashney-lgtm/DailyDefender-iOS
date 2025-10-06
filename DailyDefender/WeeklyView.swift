import SwiftUI
import UIKit

struct WeeklyView: View {
    @EnvironmentObject var store: HabitStore

    // MARK: - Week Key (ISO week, Monday-start)
    private var weekKey: String { Self.isoWeekKey(for: Date()) }
    private static func isoWeekKey(for date: Date) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2 // Monday
        let y = cal.component(.yearForWeekOfYear, from: date)
        let w = cal.component(.weekOfYear, from: date)
        return String(format: "%04d-W%02d", y, w)
    }

    // MARK: - Weekly Totals (display only; wire to store as needed)
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

    // MARK: - Weekly Text State (persisted per week)
    @State private var winsLosses: String = ""
    @State private var phys: String = ""
    @State private var prayer: String = ""
    @State private var people: String = ""
    @State private var production: String = ""
    @State private var carryText: String = ""
    @State private var carryDone: Bool = false
    @State private var oneThingNextWeek: String = ""
    @State private var journalNotes: String = ""

    // MARK: - UI State
    @State private var showShield = false
    @State private var showProfileEdit = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navy900.ignoresSafeArea()

                List {
                    // === Progress strip (matches Daily placement/style) ===
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
                        title: "Wins / Losses",
                        countText: nil,
                        subtitle: "",
                        text: $winsLosses
                    )

                    // === Physiology ===
                    weeklySection(
                        title: "Physiology",
                        countText: "\(physCount)/\(perPillarCap)",
                        subtitle: "   The body is the universal address of your existence",
                        text: $phys
                    )

                    // === Piety ===
                    weeklySection(
                        title: "Piety",
                        countText: "\(pietyCount)/\(perPillarCap)",
                        subtitle: "   Using mystery & awe as the spirit speaks for the soul",
                        text: $prayer
                    )

                    // === People ===
                    weeklySection(
                        title: "People",
                        countText: "\(peopleCount)/\(perPillarCap)",
                        subtitle: "   Team Human: herd animals who exist in each other",
                        text: $people
                    )

                    // === Production ===
                    weeklySection(
                        title: "Production",
                        countText: "\(prodCount)/\(perPillarCap)",
                        subtitle: "   A man produces more than he consumes",
                        text: $production
                    )

                    // === 🎯 This Week's One Thing Done? (checkbox on right) ===
                    weeklyCarryoverSection(
                        leadingEmoji: "🎯",
                        title: "This Week’s One Thing Done?",
                        text: $carryText,
                        isDone: $carryDone
                    )

                    // === 🎯 One Thing for Next Week ===
                    weeklySimpleSection(
                        leadingEmoji: "🎯",
                        title: "One Thing for Next Week",
                        subtitle: "",
                        text: $oneThingNextWeek
                    )

                    // === 📓 Extra Notes ===
                    weeklySimpleSection(
                        leadingEmoji: "📓",
                        title: "Extra Notes",
                        subtitle: "",
                        text: $journalNotes
                    )

                    // === Share (outlined; not full width; bottom room) ===
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Spacer().frame(height: 6)
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
                            .padding(.horizontal, 12)
                            Spacer().frame(height: 2)
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.navy900)

                    // Bottom spacer so Share is fully tappable
                    Section { Color.clear.frame(height: 56) }
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.navy900)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .modifier(CompactListTweaks())
            }
            // Tap outside to dismiss keyboard (matches Daily)
            .simultaneousGesture(TapGesture().onEnded { hideKeyboard() })

            // === Toolbar (standardized like Daily) ===
            .toolbar {
                // Left: Shield icon → FULL SCREEN cover
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showShield = true }) {
                        Image("four_ps")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppTheme.textSecondary.opacity(0.4), lineWidth: 1))
                            .padding(4)
                            .offset(y: -2) // optical center
                    }
                    .accessibilityLabel("Open 4 Ps Shield")
                }

                // Center: title + week key
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

                // Right: avatar (32pt) → ProfileEditView
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
                    .frame(width: 32, height: 32)                    // standardized size
                    .clipShape(RoundedRectangle(cornerRadius: 8))    // standardized radius
                    .offset(y: -2)                                    // optical center
                    .onTapGesture { showProfileEdit = true }
                    .accessibilityLabel("Profile")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.navy900, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 48) }

            // Shield page (has its own Back)
            .fullScreenCover(isPresented: $showShield) {
                ShieldPage(imageName: "four_ps")
            }
            // Profile edit sheet
            .sheet(isPresented: $showProfileEdit) {
                ProfileEditView().environmentObject(store)
            }
            .task { hydrateFromStorage() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                flushAll()
            }
        }
    }

    // MARK: - Section using your SectionHeader (Pillar sections)
    @ViewBuilder
    private func weeklySection(
        title: String,
        countText: String?, // e.g., "3/7" or nil
        subtitle: String,
        text: Binding<String>
    ) -> some View {
        Section {
            HStack(spacing: 8) {
                SectionHeader(label: title, pillar: pillarForTitle(title), countText: nil)
                    .lineLimit(1)
                    .truncationMode(.tail)
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

            BulletPlainNotesCard(text: text)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.navy900)
        }
    }

    // MARK: - Simple header row (no pillar icon) with optional leading emoji; divider shrinks first
    @ViewBuilder
    private func weeklySimpleSection(
        leadingEmoji: String? = nil,
        title: String,
        subtitle: String,
        text: Binding<String>
    ) -> some View {
        Section {
            OneLineHeaderRow(leadingEmoji: leadingEmoji, title: title)   // same font size, no wrap
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

            BulletPlainNotesCard(text: text)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.navy900)
        }
    }

    // MARK: - Carryover Section with checkbox on far right (slightly inset)
    @ViewBuilder
    private func weeklyCarryoverSection(
        leadingEmoji: String? = nil,
        title: String,
        text: Binding<String>,
        isDone: Binding<Bool>
    ) -> some View {
        Section {
            HStack(spacing: 8) {
                if let emoji = leadingEmoji {
                    Text(emoji)
                        .font(.title3)
                }

                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .layoutPriority(2)

                Spacer()

                let canMark = !text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                CheckSquare(
                    checked: isDone.wrappedValue && canMark,
                    onTap: {
                        if canMark {
                            isDone.wrappedValue.toggle()
                            saveCarryoverDone(isDone.wrappedValue)
                        }
                    }
                )
                .opacity(canMark ? 1.0 : 0.5)
                .padding(.trailing, 8) // ✅ still near edge, but pulled in a tad
            }
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(AppTheme.navy900)

            BulletPlainNotesCard(text: text)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.navy900)
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

    // MARK: - Persistence (scoped by weekKey)
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

    // MARK: - Share
    private func shareWeeklySummary() {
        let text = """
        **Weekly Check-In (\(weekKey))**
        Core Points: \(displayCoreTotal)/\(weeklyTotalCap)
        🏋 Physiology: \(physCount)/\(perPillarCap)
        🙏 Piety: \(pietyCount)/\(perPillarCap)
        👥 People: \(peopleCount)/\(perPillarCap)
        💼 Production: \(prodCount)/\(perPillarCap)

        **⚖️ Wins / Losses:**
        \(winsLosses.isBlank ? "—" : winsLosses)

        **🏋 Physiology Notes:**
        \(phys.isBlank ? "—" : phys)

        **🙏 Piety Notes:**
        \(prayer.isBlank ? "—" : prayer)

        **👥 People Notes:**
        \(people.isBlank ? "—" : people)

        **💼 Production Notes:**
        \(production.isBlank ? "—" : production)

        **🎯 This Week’s One Thing: \(carryDone ? "DONE!" : "NOT DONE")**
        \(carryText.isBlank ? "— none set last week —" : carryText)

        **🎯 One Thing Next Week:**
        \(oneThingNextWeek.isBlank ? "—" : oneThingNextWeek)

        **📓 Extra Notes:**
        \(journalNotes.isBlank ? "—" : journalNotes)
        """
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.firstKeyWindow?.rootViewController?.present(av, animated: true)
    }
}

// MARK: - One-line header with optional leading emoji; divider shrinks first (never shrink text)
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
            if let emoji = leadingEmoji {
                Text(emoji)
                    .font(.title3) // similar visual weight to Daily icons
            }

            Text(title)
                .font(.headline.weight(.semibold))          // match other headers
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .layoutPriority(2)                           // title wins space

            // Divider consumes only leftover space; collapses to zero if needed
            Spacer(minLength: 6)
                .frame(height: 1)
                .overlay(Rectangle().fill(AppTheme.divider))
                .layoutPriority(0)

            if let w = trailingWidth {
                trailing()
                    .frame(width: w, alignment: .trailing)
            } else {
                trailing()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 0)
    }
}

// MARK: - Bullet + Plain (Daily-style) Notes Card
private struct BulletPlainNotesCard: View {
    @Binding var text: String

    init(text: Binding<String>) {
        self._text = text
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surfaceUI)

            BulletCenteredTextView(
                text: $text,
                targetSingleLineHeight: 46
            )
            .frame(minHeight: 46)
            .background(Color.clear)
        }
        .padding(.horizontal, 0)
        .padding(.bottom, 4)
    }
}

private struct BulletCenteredTextView: UIViewRepresentable {
    @Binding var text: String
    var targetSingleLineHeight: CGFloat = 46

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.textColor = UIColor.white
        tv.tintColor = UIColor(AppTheme.appGreen)
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.isScrollEnabled = false
        tv.keyboardDismissMode = .interactive
        tv.textContainer.lineFragmentPadding = 0
        tv.contentInset = .zero
        tv.delegate = context.coordinator

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tv.text = "- "
            DispatchQueue.main.async { self.text = "- " }
        } else {
            tv.text = text
        }

        applyCenteredInsets(to: tv)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
        applyCenteredInsets(to: uiView)
    }

    private func applyCenteredInsets(to tv: UITextView) {
        let font = tv.font ?? UIFont.preferredFont(forTextStyle: .body)
        let asc  = font.ascender
        let desc = abs(font.descender)
        let lead = font.leading
        let line = asc + desc + lead

        let H: CGFloat = targetSingleLineHeight
        let base = max(0, (H - line) / 2)
        let top = (base).rounded(.toNearestOrEven)
        let bottom = (base + 2.0).rounded(.toNearestOrEven) // slight bottom bias

        tv.textContainerInset = UIEdgeInsets(top: top, left: 12, bottom: bottom, right: 12)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: BulletCenteredTextView
        init(_ parent: BulletCenteredTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            let raw = textView.text ?? ""
            let fixed = enforceDashBullets(raw)
            if fixed != raw {
                let sel = textView.selectedRange
                textView.text = fixed
                let delta = fixed.count - raw.count
                let newLoc = max(0, min((sel.location + delta), fixed.count))
                textView.selectedRange = NSRange(location: newLoc, length: 0)
            }
            parent.text = fixed
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText repl: String) -> Bool {
            if repl == "\n" {
                let ns = textView.text as NSString? ?? ""
                let replaced = ns.replacingCharacters(in: range, with: "\n- ")
                textView.text = replaced
                textView.selectedRange = NSRange(location: range.location + 3, length: 0)
                textViewDidChange(textView)
                return false
            }
            return true
        }

        private func enforceDashBullets(_ s: String) -> String {
            var lines = s.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
            if lines.isEmpty { return "- " }
            for i in lines.indices {
                if lines[i].isEmpty { lines[i] = "- " }
                else if !lines[i].hasPrefix("- ") { lines[i] = "- " + lines[i] }
            }
            return lines.joined(separator: "\n")
        }
    }
}

// MARK: - CheckSquare (copied from DailyView style)
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

// MARK: - Small helpers

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

private extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

private extension UIApplication {
    var firstKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
