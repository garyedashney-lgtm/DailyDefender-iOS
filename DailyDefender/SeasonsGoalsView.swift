import SwiftUI
import UIKit

fileprivate struct SeasonGoalEntry: Identifiable, Equatable {
    let id: Int64
    var text: String
    var done: Bool
}

// Android-parity codec
fileprivate let CONTROL: Character = "\u{0001}"
fileprivate let SEP: Character = "|"

fileprivate func encodeOne(_ text: String, done: Bool) -> String {
    let flag = done ? "1" : "0"
    return "\(CONTROL)\(flag)\(SEP)\(text)"
}
fileprivate func decodeOne(_ raw: String) -> SeasonGoalEntry? {
    if let f = raw.first, f == CONTROL {
        let rest = raw.dropFirst()
        if let pipe = rest.firstIndex(of: SEP) {
            let flag = String(rest[..<pipe])
            let text = String(rest[rest.index(after: pipe)...])
            return SeasonGoalEntry(id: -1, text: text, done: (flag == "1"))
        }
    }
    if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
    return SeasonGoalEntry(id: -1, text: raw, done: false)
}

struct SeasonsGoalsView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    // Header actions
    @State private var showGoalsShield = false
    @State private var showProfileEdit = false

    // Current season key like "2025-Winter"
    @State private var currentKey: String = ""
    @State private var titleParts: (name: String, year: Int) = ("", 0)

    // Per-pillar lists
    @State private var physGoals: [SeasonGoalEntry] = []
    @State private var pietyGoals: [SeasonGoalEntry] = []
    @State private var peopleGoals: [SeasonGoalEntry] = []
    @State private var prodGoals: [SeasonGoalEntry] = []

    @State private var newPhysText: String = ""
    @State private var newPietyText: String = ""
    @State private var newPeopleText: String = ""
    @State private var newProdText: String = ""

    @State private var nextPhysId: Int64 = 1
    @State private var nextPietyId: Int64 = 1
    @State private var nextPeopleId: Int64 = 1
    @State private var nextProdId: Int64 = 1

    @State private var isEditing = false

    // Focus (keep keyboard up on return)
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

                    seasonSelector

                    // 4 pillars like Monthly / Yearly
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

                    controlsRow

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 200) // generous for keyboard + Save
            }
            // ✅ Same as Monthly improvement
            .scrollDismissesKeyboard(.interactively)
        }

        .navigationBarBackButtonHidden(true)

        .toolbar {
            // LEFT — powernlove shield → full screen
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showGoalsShield = true }) {
                    Image("powernlove")
                        .resizable().scaledToFit()
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
                    Text("Season Goals")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.bottom, 10)
            }

            // RIGHT — Profile avatar → ProfileEdit
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
                .contentShape(Rectangle())
                .onTapGesture { showProfileEdit = true }
                .accessibilityLabel("Profile")
            }

            // ✅ Keyboard toolbar Done (same as Monthly)
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { hideKeyboardNow() }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.navy900, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)

        // Covers
        .fullScreenCover(isPresented: $showGoalsShield) {
            ShieldPage(imageName: "powernlove")
        }
        .sheet(isPresented: $showProfileEdit) {
            ProfileEditView().environmentObject(store)
        }

        // Seed/select initial season
        .onAppear {
            if currentKey.isEmpty {
                currentKey = store.seasonKeyForToday()
                titleParts = store.seasonTitleParts(currentKey)
                seedFromStorage()
            }
        }

        // Footer: Goals icon tapped → pop to Goals root
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("reselectTab"))) { note in
            if let page = note.object as? IosPage, page == .goals { dismiss() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .goalsTabTapped)) { _ in
            dismiss()
        }

        // Background autosave
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                persistNow(includeTrailingNew: true)
            }
        }
    }

    // MARK: - UI pieces

    private var seasonSelector: some View {
        VStack(spacing: 2) {
            HStack(alignment: .center, spacing: 8) {
                Button { saveThenStep(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .accessibilityLabel("Previous season")

                Spacer(minLength: 6)

                HStack(spacing: 6) {
                    Text(store.seasonEmoji(titleParts.name)).font(.body)
                    Text("\(titleParts.name) \(String(titleParts.year))")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Spacer(minLength: 6)

                Button { saveThenStep(by: +1) } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .accessibilityLabel("Next season")
            }

            Text(store.seasonSpan(currentKey))
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }

    private func pillarSection(
        title: String,
        emoji: String,
        pillar: Pillar,
        goals: Binding<[SeasonGoalEntry]>,
        newText: Binding<String>,
        trailingFocused: FocusState<Bool>.Binding
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(emoji)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 6) {
                if goals.wrappedValue.isEmpty && !isEditing {
                    Text("No goals yet for this season.")
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

    private func row(pillar: Pillar, index: Int, entry: SeasonGoalEntry) -> some View {
        HStack(spacing: 10) {
            Button {
                toggleDone(in: pillar, index: index)
            } label: {
                Image(systemName: entry.done ? "checkmark.square.fill" : "square")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        entry.done ? .white : AppTheme.textPrimary,
                        entry.done ? AppTheme.appGreen : .clear
                    )
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
                        physGoals.append(SeasonGoalEntry(id: nextIdAndBump(&nextPhysId), text: t, done: false))
                    case .Piety:
                        pietyGoals.append(SeasonGoalEntry(id: nextIdAndBump(&nextPietyId), text: t, done: false))
                    case .People:
                        peopleGoals.append(SeasonGoalEntry(id: nextIdAndBump(&nextPeopleId), text: t, done: false))
                    case .Production:
                        prodGoals.append(SeasonGoalEntry(id: nextIdAndBump(&nextProdId), text: t, done: false))
                    }

                    newText.wrappedValue = ""
                    persistNow()
                    trailingFocused.wrappedValue = true
                }
        }
        .padding(.vertical, 4)
    }

    private var controlsRow: some View {
        HStack {
            // Share button (always visible)
            Button {
                shareSeasonGoals()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .padding(.vertical, 8)
                .frame(width: 120)
            }
            .buttonStyle(.bordered)
            .tint(.white)

            Spacer()

            if isEditing {
                Button {
                    foldTrailingNewIntoLists()
                    persistNow(includeTrailingNew: false)
                    isEditing = false
                    hideKeyboardNow()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Save")
                    }
                    .padding(.vertical, 8)
                    .frame(width: 140)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.appGreen)
            } else {
                Button {
                    isEditing = true
                    if let firstId = firstExistingRowId() {
                        focusedRow = firstId
                    } else {
                        trailingPhysFocused = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .padding(.vertical, 8)
                    .frame(width: 140)
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Logic

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

        func seedOne(raw: [String], into goals: inout [SeasonGoalEntry], counter: inout Int64) {
            for enc in raw {
                if let decoded = decodeOne(enc) {
                    let id = nextIdAndBump(&counter)
                    goals.append(SeasonGoalEntry(id: id, text: decoded.text, done: decoded.done))
                }
            }
        }

        let physRaw   = store.seasonGoals(for: currentKey, pillar: .Physiology)
        let pietyRaw  = store.seasonGoals(for: currentKey, pillar: .Piety)
        let peopleRaw = store.seasonGoals(for: currentKey, pillar: .People)
        let prodRaw   = store.seasonGoals(for: currentKey, pillar: .Production)

        seedOne(raw: physRaw,   into: &physGoals,   counter: &nextPhysId)
        seedOne(raw: pietyRaw,  into: &pietyGoals,  counter: &nextPietyId)
        seedOne(raw: peopleRaw, into: &peopleGoals, counter: &nextPeopleId)
        seedOne(raw: prodRaw,   into: &prodGoals,   counter: &nextProdId)

        titleParts = store.seasonTitleParts(currentKey)
    }

    private func buildPayload(from goals: [SeasonGoalEntry], trailingNew: String?) -> [String] {
        var payload: [String] = []
        for g in goals {
            let t = g.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { payload.append(encodeOne(t, done: g.done)) }
        }
        if let trailing = trailingNew {
            let t = trailing.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { payload.append(encodeOne(t, done: false)) }
        }
        return payload
    }

    private func persistNow(includeTrailingNew: Bool = false) {
        let physPayload   = buildPayload(from: physGoals,   trailingNew: includeTrailingNew ? newPhysText   : nil)
        let pietyPayload  = buildPayload(from: pietyGoals,  trailingNew: includeTrailingNew ? newPietyText  : nil)
        let peoplePayload = buildPayload(from: peopleGoals, trailingNew: includeTrailingNew ? newPeopleText : nil)
        let prodPayload   = buildPayload(from: prodGoals,   trailingNew: includeTrailingNew ? newProdText   : nil)

        store.setSeasonGoals(currentKey, physPayload,   pillar: .Physiology)
        store.setSeasonGoals(currentKey, pietyPayload,  pillar: .Piety)
        store.setSeasonGoals(currentKey, peoplePayload, pillar: .People)
        store.setSeasonGoals(currentKey, prodPayload,   pillar: .Production)
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
        func splitAndInsert(goals: inout [SeasonGoalEntry], counter: inout Int64) {
            if let nl = newValue.firstIndex(of: "\n") {
                let before = String(newValue[..<nl])
                let after = newValue[newValue.index(after: nl)...].trimmingCharacters(in: .whitespacesAndNewlines)
                goals[index].text = before
                if !after.isEmpty {
                    let newId = nextIdAndBump(&counter)
                    goals.insert(SeasonGoalEntry(id: newId, text: after, done: false), at: index + 1)
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
        func submit(goals: inout [SeasonGoalEntry], counter: inout Int64) {
            guard goals.indices.contains(index) else { return }
            let t = goals[index].text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            let newId = nextIdAndBump(&counter)
            goals.insert(SeasonGoalEntry(id: newId, text: "", done: false), at: index + 1)
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
            physGoals.append(SeasonGoalEntry(id: nextIdAndBump(&nextPhysId), text: phys, done: false))
        }
        newPhysText = ""

        let piety = newPietyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !piety.isEmpty {
            pietyGoals.append(SeasonGoalEntry(id: nextIdAndBump(&nextPietyId), text: piety, done: false))
        }
        newPietyText = ""

        let people = newPeopleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !people.isEmpty {
            peopleGoals.append(SeasonGoalEntry(id: nextIdAndBump(&nextPeopleId), text: people, done: false))
        }
        newPeopleText = ""

        let prod = newProdText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !prod.isEmpty {
            prodGoals.append(SeasonGoalEntry(id: nextIdAndBump(&nextProdId), text: prod, done: false))
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

    private func saveThenStep(by delta: Int) {
        hideKeyboardNow()
        persistNow(includeTrailingNew: true)
        currentKey = store.stepSeason(currentKey, by: delta)
        seedFromStorage()
    }

    // MARK: - Share helpers

    private func buildSeasonSummaryText() -> String {
        func texts(from goals: [SeasonGoalEntry]) -> [String] {
            goals
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        let phys   = texts(from: physGoals)
        let piety  = texts(from: pietyGoals)
        let people = texts(from: peopleGoals)
        let prod   = texts(from: prodGoals)

        var parts: [String] = []
        parts.append("Season Goals – \(titleParts.name) \(titleParts.year)")
        parts.append(store.seasonSpan(currentKey))

        func appendSection(title: String, emoji: String, items: [String]) {
            guard !items.isEmpty else { return }
            parts.append("")
            parts.append("\(emoji) \(title)")
            for t in items {
                parts.append("• \(t)")
            }
        }

        appendSection(title: "Physiology", emoji: "💪", items: phys)
        appendSection(title: "Piety",      emoji: "🙏", items: piety)
        appendSection(title: "People",     emoji: "👥", items: people)
        appendSection(title: "Production", emoji: "💼", items: prod)

        return parts.joined(separator: "\n")
    }

    private func shareSeasonGoals() {
        // ✅ Commit any composing text before sharing (like Monthly)
        hideKeyboardNow()
        persistNow(includeTrailingNew: true)

        let text = buildSeasonSummaryText()
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            root.present(av, animated: true)
        }
    }

    private func hideKeyboardNow() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
