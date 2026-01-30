import SwiftUI
import Combine
import UIKit   // ← for UIActivityViewController

// MARK: - Footer navigation signal
extension Notification.Name {
    /// Post this when the Footer "Goals" icon is tapped to pop back to the main Goals page.
    static let goalsTabTapped = Notification.Name("Footer.GoalsTabTapped")
}

// MARK: - Model
fileprivate struct GoalEntry: Identifiable, Equatable {
    let id: Int64
    var text: String
    var done: Bool
}

// MARK: - Codec (parity with Android)
fileprivate let CONTROL: Character = "\u{0001}"
fileprivate let SEP: Character = "|"

fileprivate func encodeOne(_ text: String, done: Bool) -> String {
    let flag = done ? "1" : "0"
    return "\(CONTROL)\(flag)\(SEP)\(text)"
}

fileprivate func decodeOne(_ raw: String) -> GoalEntry? {
    // We inject id later; here just parse text/done
    if let first = raw.first, first == CONTROL {
        let rest = raw.dropFirst()
        if let pipe = rest.firstIndex(of: SEP) {
            let flag = String(rest[..<pipe])        // "0" or "1"
            let text = String(rest[rest.index(after: pipe)...])
            return GoalEntry(id: -1, text: text, done: (flag == "1"))
        }
    }
    // legacy/plain-line fallback: not done
    if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
    return GoalEntry(id: -1, text: raw, done: false)
}

// MARK: - View
struct MonthlyGoalsView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    // Header actions
    @State private var showGoalsShield = false
    @State private var showProfileEdit = false

    // Month
    @State private var currentYM: String = ""

    // Per-pillar data
    @State private var physGoals: [GoalEntry] = []
    @State private var pietyGoals: [GoalEntry] = []
    @State private var peopleGoals: [GoalEntry] = []
    @State private var prodGoals: [GoalEntry] = []

    @State private var newPhysText: String = ""
    @State private var newPietyText: String = ""
    @State private var newPeopleText: String = ""
    @State private var newProdText: String = ""

    @State private var nextPhysId: Int64 = 1
    @State private var nextPietyId: Int64 = 1
    @State private var nextPeopleId: Int64 = 1
    @State private var nextProdId: Int64 = 1

    // Editing
    @State private var isEditing: Bool = false

    // Focus management (keeps keyboard up on Return)
    @FocusState private var focusedRow: Int64?
    @FocusState private var trailingPhysFocused: Bool
    @FocusState private var trailingPietyFocused: Bool
    @FocusState private var trailingPeopleFocused: Bool
    @FocusState private var trailingProdFocused: Bool

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {

                    // Month selector
                    monthSelector

                    // Four P sections
                    pillarSection(
                        title: "Physiology",
                        emoji: "💪",
                        pillar: .Physiology,
                        goals: $physGoals,
                        newText: $newPhysText,
                        trailingFocused: $trailingPhysFocused
                    )

                    pillarSection(
                        title: "Piety",
                        emoji: "🙏",
                        pillar: .Piety,
                        goals: $pietyGoals,
                        newText: $newPietyText,
                        trailingFocused: $trailingPietyFocused
                    )

                    pillarSection(
                        title: "People",
                        emoji: "👥",
                        pillar: .People,
                        goals: $peopleGoals,
                        newText: $newPeopleText,
                        trailingFocused: $trailingPeopleFocused
                    )

                    pillarSection(
                        title: "Production",
                        emoji: "💼",
                        pillar: .Production,
                        goals: $prodGoals,
                        newText: $newProdText,
                        trailingFocused: $trailingProdFocused
                    )

                    // External controls
                    controlsRow

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 200)
            }
            // ✅ Makes scrolling feel modern + avoids needing global "tap to dismiss"
            .scrollDismissesKeyboard(.interactively)
        }

        // Hide default back chevron to match main Goals header style
        .navigationBarBackButtonHidden(true)

        .toolbar {
            // LEFT — Shield icon → FULL SCREEN cover
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showGoalsShield = true }) {
                    (UIImage(named: "identityncrisis") != nil
                     ? Image("identityncrisis").resizable().scaledToFit()
                     : Image("AppShieldSquare").resizable().scaledToFit()
                    )
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.textSecondary.opacity(0.4), lineWidth: 1))
                    .padding(4)
                    .offset(y: -2)
                }
                .accessibilityLabel("Open page shield")
            }

            // CENTER — Title (no subtitle)
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Text("🎯").font(.system(size: 18, weight: .regular))
                    Text("Monthly Goals")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.bottom, 10)
            }

            // RIGHT — Profile avatar → ProfileEdit
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
                .onTapGesture { showProfileEdit = true }
                .accessibilityLabel("Profile")
            }

            // ✅ KEYBOARD toolbar Done (prevents needing global tap-to-dismiss)
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { hideKeyboardNow() }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.navy900, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)

        // Shields / sheets
        .fullScreenCover(isPresented: $showGoalsShield) {
            ShieldPage(imageName: (UIImage(named: "identityncrisis") != nil ? "identityncrisis" : "AppShieldSquare"))
        }
        .sheet(isPresented: $showProfileEdit) {
            ProfileEditView().environmentObject(store)
        }

        // Seed on appear
        .onAppear {
            if currentYM.isEmpty {
                currentYM = store.ymKey()
                seedFromStorage()
            }
        }

        // Footer “Goals” button → pop to Goals hub (both signals supported)
        .onReceive(NotificationCenter.default.publisher(for: .goalsTabTapped)) { _ in
            dismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("reselectTab"))) { note in
            if let page = note.object as? IosPage, page == .goals {
                dismiss()
            }
        }

        // Autosave when app backgrounds
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                persistNow(includeTrailingNew: true)
            }
        }
    }

    // MARK: - Subviews

    private var monthSelector: some View {
        HStack(alignment: .center, spacing: 8) {
            Button { saveThenStep(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .accessibilityLabel("Previous month")

            Spacer(minLength: 6)

            HStack(spacing: 6) {
                Text("📅").font(.body)
                Text(store.ymTitle(currentYM))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer(minLength: 6)

            Button { saveThenStep(by: +1) } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .accessibilityLabel("Next month")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }

    private func pillarSection(
        title: String,
        emoji: String,
        pillar: Pillar,
        goals: Binding<[GoalEntry]>,
        newText: Binding<String>,
        trailingFocused: FocusState<Bool>.Binding
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 8) {
                Text(emoji)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, 4)

            // Card
            VStack(spacing: 6) {
                if goals.wrappedValue.isEmpty && !isEditing {
                    Text("No goals yet for this month.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                }

                ForEach(Array(goals.wrappedValue.enumerated()), id: \.element.id) { index, entry in
                    row(pillar: pillar, index: index, entry: entry)
                }

                if isEditing {
                    trailingNewRow(
                        pillar: pillar,
                        newText: newText,
                        trailingFocused: trailingFocused
                    )
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.surfaceUI)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
            )
        }
    }

    private func row(pillar: Pillar, index: Int, entry: GoalEntry) -> some View {
        HStack(spacing: 10) {
            // Compact checkbox
            Button {
                toggleDone(in: pillar, index: index)
            } label: {
                Image(systemName: entry.done ? "checkmark.square.fill" : "square")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(entry.done ? .white : AppTheme.textPrimary,
                                     entry.done ? AppTheme.appGreen : .clear)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.done ? "Mark not done" : "Mark done")

            if isEditing {
                TextField("Enter goal…", text: Binding(
                    get: {
                        switch pillar {
                        case .Physiology: return physGoals[index].text
                        case .Piety:      return pietyGoals[index].text
                        case .People:     return peopleGoals[index].text
                        case .Production: return prodGoals[index].text
                        }
                    },
                    set: { newValue in
                        handleRowTextChange(pillar: pillar, index: index, newValue: newValue)
                    }
                ))
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .submitLabel(.return)
                .focused($focusedRow, equals: entry.id)
                .onSubmit {
                    handleRowSubmit(pillar: pillar, index: index)
                }

                // Delete affordance
                Button {
                    deleteRow(in: pillar, index: index)
                    persistNow()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete")
            } else {
                // Read-only
                Text(entry.text)
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }

    private func trailingNewRow(
        pillar: Pillar,
        newText: Binding<String>,
        trailingFocused: FocusState<Bool>.Binding
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "square")
                .foregroundStyle(AppTheme.textSecondary)
                .font(.title3)

            TextField("Add another goal…", text: newText)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .submitLabel(.return)
                .focused(trailingFocused)
                .onSubmit {
                    let t = newText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }

                    switch pillar {
                    case .Physiology:
                        physGoals.append(GoalEntry(id: nextIdAndBump(&nextPhysId), text: t, done: false))
                    case .Piety:
                        pietyGoals.append(GoalEntry(id: nextIdAndBump(&nextPietyId), text: t, done: false))
                    case .People:
                        peopleGoals.append(GoalEntry(id: nextIdAndBump(&nextPeopleId), text: t, done: false))
                    case .Production:
                        prodGoals.append(GoalEntry(id: nextIdAndBump(&nextProdId), text: t, done: false))
                    }

                    newText.wrappedValue = ""
                    persistNow()
                    // Keep keyboard up for rapid entry in this pillar
                    trailingFocused.wrappedValue = true
                }
        }
        .padding(.vertical, 4)
    }

    private var controlsRow: some View {
        HStack(spacing: 12) {
            // Share button (always available)
            Button {
                shareMonthlyGoals()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .frame(width: 120)
            }
            .buttonStyle(.bordered)
            .tint(.white)

            Spacer()

            if isEditing {
                Button {
                    // Fold trailing fields (if any), then persist and exit edit mode
                    foldTrailingNewIntoLists()
                    persistNow(includeTrailingNew: false)
                    isEditing = false
                    hideKeyboardNow()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Save")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .frame(width: 120)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.appGreen)
            } else {
                Button {
                    isEditing = true
                    // Put cursor into first existing row, otherwise first trailing field
                    if let firstId = firstExistingRowId() {
                        focusedRow = firstId
                    } else {
                        trailingPhysFocused = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .frame(width: 120)
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Actions / helpers

    private func nextIdAndBump(_ counter: inout Int64) -> Int64 {
        defer { counter &+= 1 }
        return counter
    }

    private func seedFromStorage() {
        physGoals.removeAll(keepingCapacity: true)
        pietyGoals.removeAll(keepingCapacity: true)
        peopleGoals.removeAll(keepingCapacity: true)
        prodGoals.removeAll(keepingCapacity: true)

        nextPhysId = 1
        nextPietyId = 1
        nextPeopleId = 1
        nextProdId = 1

        newPhysText = ""
        newPietyText = ""
        newPeopleText = ""
        newProdText = ""

        func seedOne(raw: [String], into goals: inout [GoalEntry], counter: inout Int64) {
            for enc in raw {
                if let decoded = decodeOne(enc) {
                    let id = nextIdAndBump(&counter)
                    goals.append(GoalEntry(id: id, text: decoded.text, done: decoded.done))
                }
            }
        }

        let physRaw   = store.monthlyGoals(for: currentYM, pillar: .Physiology)
        let pietyRaw  = store.monthlyGoals(for: currentYM, pillar: .Piety)
        let peopleRaw = store.monthlyGoals(for: currentYM, pillar: .People)
        let prodRaw   = store.monthlyGoals(for: currentYM, pillar: .Production)

        seedOne(raw: physRaw,   into: &physGoals,   counter: &nextPhysId)
        seedOne(raw: pietyRaw,  into: &pietyGoals,  counter: &nextPietyId)
        seedOne(raw: peopleRaw, into: &peopleGoals, counter: &nextPeopleId)
        seedOne(raw: prodRaw,   into: &prodGoals,   counter: &nextProdId)
    }

    private func buildPayload(from goals: [GoalEntry], trailingNew: String?) -> [String] {
        var payload: [String] = []
        for g in goals {
            let t = g.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty {
                payload.append(encodeOne(t, done: g.done))
            }
        }
        if let trailing = trailingNew {
            let t = trailing.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty {
                payload.append(encodeOne(t, done: false))
            }
        }
        return payload
    }

    private func persistNow(includeTrailingNew: Bool = false) {
        let physPayload   = buildPayload(from: physGoals,   trailingNew: includeTrailingNew ? newPhysText   : nil)
        let pietyPayload  = buildPayload(from: pietyGoals,  trailingNew: includeTrailingNew ? newPietyText  : nil)
        let peoplePayload = buildPayload(from: peopleGoals, trailingNew: includeTrailingNew ? newPeopleText : nil)
        let prodPayload   = buildPayload(from: prodGoals,   trailingNew: includeTrailingNew ? newProdText   : nil)

        store.setMonthlyGoals(physPayload,   for: currentYM, pillar: .Physiology)
        store.setMonthlyGoals(pietyPayload,  for: currentYM, pillar: .Piety)
        store.setMonthlyGoals(peoplePayload, for: currentYM, pillar: .People)
        store.setMonthlyGoals(prodPayload,   for: currentYM, pillar: .Production)
    }

    private func toggleDone(in pillar: Pillar, index: Int) {
        switch pillar {
        case .Physiology:
            guard physGoals.indices.contains(index) else { return }
            physGoals[index].done.toggle()
        case .Piety:
            guard pietyGoals.indices.contains(index) else { return }
            pietyGoals[index].done.toggle()
        case .People:
            guard peopleGoals.indices.contains(index) else { return }
            peopleGoals[index].done.toggle()
        case .Production:
            guard prodGoals.indices.contains(index) else { return }
            prodGoals[index].done.toggle()
        }
        persistNow()
    }

    private func handleRowTextChange(pillar: Pillar, index: Int, newValue: String) {
        func splitAndInsert(
            goals: inout [GoalEntry],
            counter: inout Int64
        ) {
            if let nl = newValue.firstIndex(of: "\n") {
                let before = String(newValue[..<nl])
                let after = newValue[newValue.index(after: nl)...].trimmingCharacters(in: .whitespacesAndNewlines)
                goals[index].text = before
                if !after.isEmpty {
                    let newId = nextIdAndBump(&counter)
                    goals.insert(GoalEntry(id: newId, text: after, done: false), at: index + 1)
                    DispatchQueue.main.async {
                        focusedRow = newId
                    }
                }
                persistNow()
            } else {
                goals[index].text = newValue
            }
        }

        switch pillar {
        case .Physiology:
            guard physGoals.indices.contains(index) else { return }
            splitAndInsert(goals: &physGoals, counter: &nextPhysId)
        case .Piety:
            guard pietyGoals.indices.contains(index) else { return }
            splitAndInsert(goals: &pietyGoals, counter: &nextPietyId)
        case .People:
            guard peopleGoals.indices.contains(index) else { return }
            splitAndInsert(goals: &peopleGoals, counter: &nextPeopleId)
        case .Production:
            guard prodGoals.indices.contains(index) else { return }
            splitAndInsert(goals: &prodGoals, counter: &nextProdId)
        }
    }

    private func handleRowSubmit(pillar: Pillar, index: Int) {
        func submit(goals: inout [GoalEntry], counter: inout Int64) {
            guard goals.indices.contains(index) else { return }
            let t = goals[index].text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            let newId = nextIdAndBump(&counter)
            goals.insert(GoalEntry(id: newId, text: "", done: false), at: index + 1)
            persistNow()
            DispatchQueue.main.async {
                focusedRow = newId
            }
        }

        switch pillar {
        case .Physiology:
            submit(goals: &physGoals, counter: &nextPhysId)
        case .Piety:
            submit(goals: &pietyGoals, counter: &nextPietyId)
        case .People:
            submit(goals: &peopleGoals, counter: &nextPeopleId)
        case .Production:
            submit(goals: &prodGoals, counter: &nextProdId)
        }
    }

    private func deleteRow(in pillar: Pillar, index: Int) {
        switch pillar {
        case .Physiology:
            guard physGoals.indices.contains(index) else { return }
            physGoals.remove(at: index)
        case .Piety:
            guard pietyGoals.indices.contains(index) else { return }
            pietyGoals.remove(at: index)
        case .People:
            guard peopleGoals.indices.contains(index) else { return }
            peopleGoals.remove(at: index)
        case .Production:
            guard prodGoals.indices.contains(index) else { return }
            prodGoals.remove(at: index)
        }
    }

    private func foldTrailingNewIntoLists() {
        let phys = newPhysText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !phys.isEmpty {
            physGoals.append(GoalEntry(id: nextIdAndBump(&nextPhysId), text: phys, done: false))
        }
        newPhysText = ""

        let piety = newPietyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !piety.isEmpty {
            pietyGoals.append(GoalEntry(id: nextIdAndBump(&nextPietyId), text: piety, done: false))
        }
        newPietyText = ""

        let people = newPeopleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !people.isEmpty {
            peopleGoals.append(GoalEntry(id: nextIdAndBump(&nextPeopleId), text: people, done: false))
        }
        newPeopleText = ""

        let prod = newProdText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !prod.isEmpty {
            prodGoals.append(GoalEntry(id: nextIdAndBump(&nextProdId), text: prod, done: false))
        }
        newProdText = ""
    }

    private func firstExistingRowId() -> Int64? {
        if let g = physGoals.first { return g.id }
        if let g = pietyGoals.first { return g.id }
        if let g = peopleGoals.first { return g.id }
        if let g = prodGoals.first { return g.id }
        return nil
    }

    private func saveThenStep(by months: Int) {
        // Save everything, including trailing "new" text, then move month
        persistNow(includeTrailingNew: true)
        hideKeyboardNow()
        currentYM = store.step(currentYM, by: months)
        seedFromStorage()
    }

    private func shareMonthlyGoals() {
        // Commit any composing text
        hideKeyboardNow()
        persistNow(includeTrailingNew: true)

        func texts(from goals: [GoalEntry]) -> [String] {
            goals
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        let phys  = texts(from: physGoals)
        let piety = texts(from: pietyGoals)
        let people = texts(from: peopleGoals)
        let prod  = texts(from: prodGoals)

        var parts: [String] = []
        parts.append("Monthly Goals — \(store.ymTitle(currentYM))")

        func appendSection(title: String, emoji: String, items: [String]) {
            guard !items.isEmpty else { return }
            parts.append("") // blank line
            parts.append("\(emoji) \(title)")
            for t in items {
                parts.append("• \(t)")
            }
        }

        appendSection(title: "Physiology", emoji: "💪", items: phys)
        appendSection(title: "Piety",      emoji: "🙏", items: piety)
        appendSection(title: "People",     emoji: "👥", items: people)
        appendSection(title: "Production", emoji: "💼", items: prod)

        let text = parts.joined(separator: "\n")

        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }

        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        root.present(vc, animated: true, completion: nil)
    }

    private func hideKeyboardNow() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
