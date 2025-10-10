import SwiftUI

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

    // In-memory list + edit state
    @State private var goals: [SeasonGoalEntry] = []
    @State private var isEditing = false
    @State private var newGoalText = ""
    @State private var nextId: Int64 = 1

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {

                    seasonSelector

                    goalsCard

                    controlsRow

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
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

        // Footer: if user taps Goals while already on Goals, pop back to Goals root
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("reselectTab"))) { note in
            if let page = note.object as? IosPage, page == .goals {
                dismiss()
            }
        }

        // Background autosave
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                persistNow(includeTrailingNew: true)
            }
        }
    }

    // MARK: UI pieces

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

    private var goalsCard: some View {
        VStack(spacing: 6) {
            if goals.isEmpty && !isEditing {
                Text("No goals yet for this season.")
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

    private func row(index: Int, entry: SeasonGoalEntry) -> some View {
        HStack(spacing: 10) {
            Button {
                toggleDone(index: index)
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
                    get: { goals[index].text },
                    set: { newValue in
                        if let nl = newValue.firstIndex(of: "\n") {
                            let before = String(newValue[..<nl])
                            let after = newValue[newValue.index(after: nl)...].trimmingCharacters(in: .whitespacesAndNewlines)
                            goals[index].text = before
                            if !after.isEmpty {
                                goals.insert(SeasonGoalEntry(id: nextIdAndBump(), text: after, done: false), at: index + 1)
                            }
                            persistNow()
                        } else {
                            goals[index].text = newValue
                        }
                    }
                ))
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .submitLabel(.done)

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
                .submitLabel(.done)
                .onSubmit {
                    let t = newGoalText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }
                    goals.append(SeasonGoalEntry(id: nextIdAndBump(), text: t, done: false))
                    newGoalText = ""
                    persistNow()
                }
        }
        .padding(.vertical, 4)
    }

    private var controlsRow: some View {
        HStack {
            Spacer()
            if isEditing {
                Button {
                    let t = newGoalText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty {
                        goals.append(SeasonGoalEntry(id: nextIdAndBump(), text: t, done: false))
                        newGoalText = ""
                    }
                    persistNow()
                    isEditing = false
                    hideKeyboardNow()
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

    // MARK: logic

    private func nextIdAndBump() -> Int64 {
        defer { nextId &+= 1 }
        return nextId
    }

    private func seedFromStorage() {
        goals.removeAll(keepingCapacity: true)
        nextId = 1
        let raw = store.seasonGoals(for: currentKey)
        for enc in raw {
            if var e = decodeOne(enc) {
                e = SeasonGoalEntry(id: nextIdAndBump(), text: e.text, done: e.done)
                goals.append(e)
            }
        }
        newGoalText = ""
        titleParts = store.seasonTitleParts(currentKey)
    }

    private func persistNow(includeTrailingNew: Bool = false) {
        var payload: [String] = []
        for g in goals {
            let t = g.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { payload.append(encodeOne(t, done: g.done)) }
        }
        if includeTrailingNew {
            let t = newGoalText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { payload.append(encodeOne(t, done: false)) }
        }
        store.setSeasonGoals(currentKey, payload)
    }

    private func toggleDone(index: Int) {
        guard goals.indices.contains(index) else { return }
        goals[index].done.toggle()
        persistNow()
    }

    private func saveThenStep(by delta: Int) {
        hideKeyboardNow()
        persistNow(includeTrailingNew: true)
        currentKey = store.stepSeason(currentKey, by: delta)
        seedFromStorage()
    }
}

// MARK: - keyboard helper
fileprivate extension View {
    func hideKeyboardNow() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

