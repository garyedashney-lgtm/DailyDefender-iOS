import SwiftUI
import Combine

// MARK: - Model (same row model as Monthly)
fileprivate struct GoalEntry: Identifiable, Equatable {
    let id: Int64
    var text: String
    var done: Bool
}

// MARK: - Codec (parity with Android / Monthly)
fileprivate let CONTROL: Character = "\u{0001}"
fileprivate let SEP: Character = "|"

fileprivate func encodeOne(_ text: String, done: Bool) -> String {
    let flag = done ? "1" : "0"
    return "\(CONTROL)\(flag)\(SEP)\(text)"
}

fileprivate func decodeOne(_ raw: String) -> GoalEntry? {
    if let first = raw.first, first == CONTROL {
        let rest = raw.dropFirst()
        if let pipe = rest.firstIndex(of: SEP) {
            let flag = String(rest[..<pipe])        // "0" or "1"
            let text = String(rest[rest.index(after: pipe)...])
            return GoalEntry(id: -1, text: text, done: (flag == "1"))
        }
    }
    if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
    return GoalEntry(id: -1, text: raw, done: false)
}

struct YearlyGoalsView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    // Header actions
    @State private var showGoalsShield = false
    @State private var showProfileEdit = false

    // Year / data state
    @State private var currentYear: Int = Calendar.current.component(.year, from: Date())
    @State private var goals: [GoalEntry] = []
    @State private var isEditing: Bool = false
    @State private var newGoalText: String = ""
    @State private var nextId: Int64 = 1

    // Focus management to keep keyboard up
    @FocusState private var focusedRow: Int64?
    @FocusState private var trailingFocused: Bool

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {

                    // === Year selector ===
                    yearSelector

                    // === Goals card ===
                    goalsCard

                    // === Controls (Edit / Save) ===
                    controlsRow

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
        }
        .withKeyboardDismiss()                // Keeps green Done toolbar (optional) + background tap-to-dismiss
        .navigationBarBackButtonHidden(true)

        // === Toolbar (match Goals/Monthly/Seasonal) ===
        .toolbar {
            // LEFT — Shield (full-screen cover)
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

            // CENTER — Title
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Text("🎯").font(.system(size: 18, weight: .regular))
                    Text("Yearly Goals")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.bottom, 10)
            }

            // RIGHT — Avatar → ProfileEdit
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
        .onAppear { seedFromStorage() }

        // Footer “Goals” tab → return to main Goals page
        .onReceive(NotificationCenter.default.publisher(for: .goalsTabTapped)) { _ in
            dismiss()
        }
        // Also support the older/broader reselectTab pattern (parity with Monthly)
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

    private var yearSelector: some View {
        HStack(alignment: .center, spacing: 8) {
            Button { saveThenStep(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .accessibilityLabel("Previous year")

            Spacer(minLength: 6)

            HStack(spacing: 6) {
                Text("📅").font(.body)
                // No formatter → no commas in year
                Text("Year \(String(currentYear))")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer(minLength: 6)

            Button { saveThenStep(by: +1) } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .accessibilityLabel("Next year")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }

    private var goalsCard: some View {
        VStack(spacing: 6) {
            if goals.isEmpty && !isEditing {
                Text("No goals yet for this year.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            }

            ForEach(Array(goals.enumerated()), id: \.element.id) { index, entry in
                row(index: index, entry: entry)
            }

            if isEditing { trailingNewRow }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surfaceUI)
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
        )
    }

    private func row(index: Int, entry: GoalEntry) -> some View {
        HStack(spacing: 10) {
            // Compact checkbox
            Button { toggleDone(index: index) } label: {
                Image(systemName: entry.done ? "checkmark.square.fill" : "square")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(entry.done ? .white : AppTheme.textPrimary,
                                     entry.done ? AppTheme.appGreen : .clear)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.done ? "Mark not done" : "Mark done")

            if isEditing {
                // Editable row
                TextField("Enter goal…", text: Binding(
                    get: { goals[index].text },
                    set: { newValue in
                        // If a newline sneaks in (paste), split into a new row
                        if let nl = newValue.firstIndex(of: "\n") {
                            let before = String(newValue[..<nl])
                            let after = newValue[newValue.index(after: nl)...].trimmingCharacters(in: .whitespacesAndNewlines)
                            goals[index].text = before
                            if !after.isEmpty {
                                let newId = nextIdAndBump()
                                goals.insert(GoalEntry(id: newId, text: after, done: false), at: index + 1)
                                focusedRow = newId                      // keep keyboard up → focus new row
                            }
                            persistNow()
                        } else {
                            goals[index].text = newValue
                        }
                    }
                ))
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .submitLabel(.return)      // Return should add a row and KEEP focus/keyboard
                .focused($focusedRow, equals: entry.id)
                .onSubmit {
                    let t = goals[index].text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }
                    let newId = nextIdAndBump()
                    goals.insert(GoalEntry(id: newId, text: "", done: false), at: index + 1)
                    persistNow()
                    focusedRow = newId      // ← immediately focus the new row (keyboard stays up)
                }

                // Delete
                Button {
                    goals.remove(at: index)
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

    private var trailingNewRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "square")
                .foregroundStyle(AppTheme.textSecondary)
                .font(.title3)

            TextField("Add another goal…", text: $newGoalText)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .submitLabel(.return)
                .focused($trailingFocused)
                .onSubmit {
                    let t = newGoalText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }
                    goals.append(GoalEntry(id: nextIdAndBump(), text: t, done: false))
                    newGoalText = ""
                    persistNow()
                    // Keep keyboard up on the trailing field so user can keep entering
                    trailingFocused = true
                }
        }
        .padding(.vertical, 4)
    }

    private var controlsRow: some View {
        HStack {
            Spacer()
            if isEditing {
                Button {
                    // Fold trailing field, persist, exit edit mode
                    let t = newGoalText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty {
                        goals.append(GoalEntry(id: nextIdAndBump(), text: t, done: false))
                        newGoalText = ""
                    }
                    persistNow()
                    isEditing = false
                    dismissKeyboard()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Save")
                    }
                    .padding(.vertical, 10)
                    .frame(width: 160)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.appGreen)
            } else {
                Button {
                    isEditing = true
                    // Put cursor into trailing field if there are no rows, otherwise first row
                    if goals.isEmpty {
                        trailingFocused = true
                    } else {
                        focusedRow = goals.first?.id
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .padding(.vertical, 10)
                    .frame(width: 160)
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Actions / helpers

    private func yearKey(_ y: Int) -> String { String(y) }

    private func nextIdAndBump() -> Int64 {
        defer { nextId &+= 1 }
        return nextId
    }

    private func seedFromStorage() {
        goals.removeAll(keepingCapacity: true)
        nextId = 1
        let raw = store.yearlyGoals(for: yearKey(currentYear))
        for enc in raw {
            if var e = decodeOne(enc) {
                e = GoalEntry(id: nextIdAndBump(), text: e.text, done: e.done)
                goals.append(e)
            }
        }
        newGoalText = ""
    }

    private func persistNow(includeTrailingNew: Bool = false) {
        var payload: [String] = []
        for g in goals {
            let t = g.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty {
                payload.append(encodeOne(t, done: g.done))
            }
        }
        if includeTrailingNew {
            let t = newGoalText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty {
                payload.append(encodeOne(t, done: false))
            }
        }
        store.setYearlyGoals(payload, for: yearKey(currentYear))
    }

    private func toggleDone(index: Int) {
        guard goals.indices.contains(index) else { return }
        goals[index].done.toggle()
        persistNow()
    }

    private func saveThenStep(by years: Int) {
        dismissKeyboard()
        persistNow(includeTrailingNew: true)
        currentYear += years
        seedFromStorage()
    }
}
