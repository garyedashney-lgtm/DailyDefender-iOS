import SwiftUI

struct JournalHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var session: SessionViewModel
    @ObservedObject private var journalStore = JournalMemoryStore.shared   // JSON-on-disk persistence

    // Header actions
    @State private var showJournalShield = false
    @State private var showProfileEdit = false

    // Navigation
    private enum JournalRoute: Hashable {
        case freeFlowNew
        case gratitudeNew
        case freeFlowExisting(JournalEntryIOS)
        case blessingTallyNew
        case blessingTallyExisting(JournalEntryIOS)
        case ctwNew
        case ctwExisting(JournalEntryIOS)
        case tenRNew
        case tenRExisting(JournalEntryIOS)
        case scwNew
        case scwExisting(JournalEntryIOS)
        case search
    }
    @State private var path: [JournalRoute] = []

    // Optional external callbacks
    var onFreeFlow: () -> Void = {}
    var onGratitude: () -> Void = {}
    var onCageTheWolf: () -> Void = {}
    var onTenR: () -> Void = {}
    var onBlessingTally: () -> Void = {}
    var onSelfCareWriting: () -> Void = {}
    var onSearch: () -> Void = {}

    private let journalShieldAsset = "AppShieldSquare"

    var body: some View {
        if !session.isPro {
            PaywallCardView(title: "Pro Feature")
        } else {
            NavigationStack(path: $path) {
                ZStack {
                    AppTheme.navy900.ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            // --- Section: New Journal ---
                            SectionHeaderCustom(title: "New Journal", emoji: "📒")

                            JournalCardRow(title: "Free Flow", subtitle: "– Talk!", emoji: "📓") {
                                path.append(.freeFlowNew)
                                onFreeFlow()
                            }

                            JournalCardRow(title: "Gratitude", subtitle: "– Thanks!", emoji: "🙏") {
                                path.append(.gratitudeNew)
                                onGratitude()
                            }

                            JournalCardRow(title: "3 Blessings", subtitle: "– Tally!", emoji: "✨") {
                                path.append(.blessingTallyNew)
                                onBlessingTally()
                            }

                            JournalCardRow(title: "Cage The Wolf", subtitle: "– Tempted?", emoji: "🐺") {
                                path.append(.ctwNew)
                                onCageTheWolf()
                            }

                            JournalCardRow(title: "10R Process", subtitle: "– Triggered?", emoji: "📝") {
                                path.append(.tenRNew)
                                onTenR()
                            }

                            JournalCardRow(title: "Self Care Writing", subtitle: "– Traumatized?", emoji: "🪞") {
                                path.append(.scwNew)
                                onSelfCareWriting()
                            }

                            // --- Section: Journal Library ---
                            SectionHeaderCustom(title: "Journal Library", emoji: "📚")

                            JournalCardRow(title: "Journal Library Search", emoji: "🔍") {
                                path.append(.search)
                                onSearch()
                            }

                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.icloud")
                                    .foregroundStyle(AppTheme.appGreen)
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Your journals are saved on this device and included in iCloud backups.")
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 6)

                            Spacer(minLength: 56)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }
                // === Toolbar/Header ===
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showJournalShield = true }) {
                            (UIImage(named: journalShieldAsset) != nil
                             ? Image(journalShieldAsset).resizable().scaledToFit()
                             : Image("AppShieldSquare").resizable().scaledToFit())
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppTheme.textSecondary.opacity(0.4), lineWidth: 1))
                            .padding(4)
                            .offset(y: -2)
                        }
                        .accessibilityLabel("Open Journal shield")
                    }

                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 6) {
                            Text("Journal")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        .padding(.bottom, 10)
                    }

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
                        .onTapGesture { showProfileEdit = true }
                        .accessibilityLabel("Profile")
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(AppTheme.navy900, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 48) }

                // Footer tap back
                .onReceive(NotificationCenter.default.publisher(for: .JumpToJournalHome)) { _ in
                    path = []
                }

                .fullScreenCover(isPresented: $showJournalShield) {
                    ShieldPage(imageName: journalShieldAsset)
                }

                .sheet(isPresented: $showProfileEdit) {
                    ProfileEditView().environmentObject(store)
                }

                // === Destinations ===
                .navigationDestination(for: JournalRoute.self) { route in
                    switch route {

                    // --- Free Flow ---
                    case .freeFlowNew:
                        FreeFlowEditorView(
                            initialTitle: "", initialBody: "",
                            initialCreatedAt: Date(), initialUpdatedAt: nil,
                            isEditingExisting: false,
                            onBack: { dismiss() },
                            onSave: { title, body, created in
                                JournalMemoryStore.shared.addFreeFlow(title: title, body: body, createdAt: created)
                                dismiss()
                            },
                            onDelete: {}
                        ).environmentObject(store)

                    case .freeFlowExisting(let entry):
                        FreeFlowEditorView(
                            initialTitle: entry.title,
                            initialBody: entry.content,
                            initialCreatedAt: Date(timeIntervalSince1970: TimeInterval(entry.dateMillis) / 1000),
                            initialUpdatedAt: Date(timeIntervalSince1970: TimeInterval(entry.updatedAt) / 1000),
                            isEditingExisting: true,
                            onBack: { dismiss() },
                            onSave: { title, body, created in
                                JournalMemoryStore.shared.updateEntry(id: entry.id, title: title, body: body, createdAt: created)
                                dismiss()
                            },
                            onDelete: {
                                JournalMemoryStore.shared.delete(ids: [entry.id])
                                dismiss()
                            }
                        ).environmentObject(store)

                    // --- 3 Blessings ---
                    case .blessingTallyNew:
                        BlessingTallyEditorView(
                            initialTitle: "3 Blessings",
                            initialCreatedAt: Date(),
                            initialAnswers: ("", "", ""),
                            isEditingExisting: false,
                            onBack: { dismiss() },
                            onSave: { title, body, created in
                                JournalMemoryStore.shared.addFreeFlow(title: title, body: body, createdAt: created)
                                dismiss()
                            },
                            onDelete: {}
                        ).environmentObject(store)

                    case .blessingTallyExisting(let entry):
                        BlessingTallyEditorView(
                            initialTitle: entry.title.isEmpty ? "3 Blessings" : entry.title,
                            initialCreatedAt: Date(timeIntervalSince1970: TimeInterval(entry.dateMillis) / 1000),
                            initialAnswers: answersTuple(from: entry.content),
                            isEditingExisting: true,
                            onBack: { dismiss() },
                            onSave: { title, body, created in
                                JournalMemoryStore.shared.updateEntry(id: entry.id, title: title, body: body, createdAt: created)
                                dismiss()
                            },
                            onDelete: {
                                JournalMemoryStore.shared.delete(ids: [entry.id])
                                dismiss()
                            }
                        ).environmentObject(store)

                    // --- Gratitude ---
                    case .gratitudeNew:
                        GratitudeEditorView(
                            initialTitle: "Gratitude",
                            initialBody: "",
                            initialCreatedAt: Date(),
                            initialUpdatedAt: Date(),
                            isEditingExisting: false,
                            onBack: { dismiss() },
                            onSave: { title, body, created in
                                JournalMemoryStore.shared.addFreeFlow(title: title, body: body, createdAt: created)
                                dismiss()
                            },
                            onDelete: {}
                        ).environmentObject(store)

                    // --- Cage the Wolf ---
                    case .ctwNew:
                        CageTheWolfEditorView(
                            initialTitle: "Cage The Wolf",
                            initialCreatedAt: Date(),
                            initialAnswers: Array(repeating: "", count: Ctw.inputCount),
                            isEditingExisting: false,
                            onBack: { dismiss() },
                            onSave: { title, body, created in
                                JournalMemoryStore.shared.addFreeFlow(title: title, body: body, createdAt: created)
                                dismiss()
                            },
                            onDelete: {}
                        ).environmentObject(store)

                    case .ctwExisting(let entry):
                        let parsed = parseCtwBody(entry.content)
                        let answers = Array(parsed.prefix(Ctw.inputCount))
                        CageTheWolfEditorView(
                            initialTitle: entry.title.isEmpty ? "Cage The Wolf" : entry.title,
                            initialCreatedAt: Date(timeIntervalSince1970: TimeInterval(entry.dateMillis) / 1000),
                            initialAnswers: answers,
                            isEditingExisting: true,
                            onBack: { dismiss() },
                            onSave: { title, body, created in
                                JournalMemoryStore.shared.updateEntry(id: entry.id, title: title, body: body, createdAt: created)
                                dismiss()
                            },
                            onDelete: {
                                JournalMemoryStore.shared.delete(ids: [entry.id])
                                dismiss()
                            }
                        ).environmentObject(store)

                    // --- 10R Process ---
                    case .tenRNew:
                        TenREditorView(
                            initialTitle: "10R Process",
                            initialCreatedAt: Date(),
                            initialAnswers: Array(repeating: "", count: TenR.inputCount),
                            isEditingExisting: false,
                            onBack: { dismiss() },
                            onSave: { title, body, created in
                                JournalMemoryStore.shared.addFreeFlow(title: title, body: body, createdAt: created)
                                dismiss()
                            },
                            onDelete: {}
                        ).environmentObject(store)

                    case .tenRExisting(let entry):
                        let parsed = parseTenRBody(entry.content)
                        let answers = Array(parsed.prefix(TenR.inputCount))
                        TenREditorView(
                            initialTitle: entry.title.isEmpty ? "10R Process" : entry.title,
                            initialCreatedAt: Date(timeIntervalSince1970: TimeInterval(entry.dateMillis) / 1000),
                            initialUpdatedAt: Date(timeIntervalSince1970: TimeInterval(entry.updatedAt) / 1000),
                            initialAnswers: answers,
                            isEditingExisting: true,
                            onBack: { dismiss() },
                            onSave: { title, body, created in
                                JournalMemoryStore.shared.updateEntry(id: entry.id, title: title, body: body, createdAt: created)
                                dismiss()
                            },
                            onDelete: {
                                JournalMemoryStore.shared.delete(ids: [entry.id])
                                dismiss()
                            }
                        ).environmentObject(store)

                    // --- Self Care Writing ---
                    case .scwNew:
                        ScwEditorView(
                            initialTitle: "Self Care Writing",
                            initialCreatedAt: Date(),
                            initialAnswers: Array(repeating: "", count: Scw.inputCount),
                            isEditingExisting: false,
                            onBack: { dismiss() },
                            onSave: { title, body, created in
                                JournalMemoryStore.shared.addFreeFlow(title: title, body: body, createdAt: created)
                                dismiss()
                            },
                            onDelete: {}
                        ).environmentObject(store)

                    case .scwExisting(let entry):
                        let parsed = parseScwBody(entry.content)
                        let answers = Array(parsed.prefix(Scw.inputCount))
                        ScwEditorView(
                            initialTitle: entry.title.isEmpty ? "Self Care Writing" : entry.title,
                            initialCreatedAt: Date(timeIntervalSince1970: TimeInterval(entry.dateMillis) / 1000),
                            initialUpdatedAt: Date(timeIntervalSince1970: TimeInterval(entry.updatedAt) / 1000),
                            initialAnswers: answers,
                            isEditingExisting: true,
                            onBack: { dismiss() },
                            onSave: { title, body, created in
                                JournalMemoryStore.shared.updateEntry(id: entry.id, title: title, body: body, createdAt: created)
                                dismiss()
                            },
                            onDelete: {
                                JournalMemoryStore.shared.delete(ids: [entry.id])
                                dismiss()
                            }
                        ).environmentObject(store)

                    // --- Search ---
                    case .search:
                        JournalLibrarySearchView(
                            allEntries: journalStore.entries,
                            onOpen: { tapped in
                                if looksLikeCtwLocal(tapped.content) {
                                    path.append(.ctwExisting(tapped))
                                } else if looksLikeBlessingTallyLocal(tapped.content) {
                                    path.append(.blessingTallyExisting(tapped))
                                } else if looksLikeTenRLocal(tapped.title, tapped.content) {
                                    path.append(.tenRExisting(tapped))
                                } else if looksLikeScwLocalHome(tapped.content) {
                                    path.append(.scwExisting(tapped))
                                } else {
                                    path.append(.freeFlowExisting(tapped))
                                }
                            },
                            onDelete: { ids in JournalMemoryStore.shared.delete(ids: ids) }
                        ).environmentObject(store)
                    }
                }
            }
        }
    }
}

// MARK: - Local detectors used for routing from Library
private func looksLikeBlessingTallyLocal(_ content: String) -> Bool {
    let pattern = #"(?m)^\s*1\s*[—-]\s*What are three things from today that went well\.?"#
    return content.range(of: pattern, options: .regularExpression) != nil
}

private func looksLikeCtwLocal(_ content: String) -> Bool {
    let step1 = #"(?m)^\s*1\s*[—-]\s*Set rules and claim a higher self\s*$"#
    if content.range(of: step1, options: .regularExpression) != nil { return true }
    if content.contains("## 1) Claiming Identity")
        && content.contains("## 2) Identify the Wolf")
        && content.contains("## 3) Train the Wolf") {
        return true
    }
    return false
}

private func looksLikeTenRLocal(_ title: String, _ content: String) -> Bool {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.range(of: "10R Process", options: .caseInsensitive) != nil {
        return true
    }
    let pattern = #"(?m)^\s*1\s*[—-]\s*Recognize"#
    return content.range(of: pattern, options: .regularExpression) != nil
}

// Renamed to avoid any duplicate with other files.
private func looksLikeScwLocalHome(_ content: String) -> Bool {
    let step1 = #"(?m)^\s*1\s*[—-]\s*What, Why, How\s*$"#
    return content.range(of: step1, options: .regularExpression) != nil
}

// MARK: - Section Header
private struct SectionHeaderCustom: View {
    let title: String
    let emoji: String
    var body: some View {
        HStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 22))
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }
}

// MARK: - Journal Card Row
private struct JournalCardRow: View {
    let title: String
    var subtitle: String? = nil
    let emoji: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.appGreen.opacity(0.16))
                        .frame(width: 40, height: 40)
                    Text(emoji)
                        .font(.system(size: 20))
                }

                HStack(spacing: 6) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote.italic())
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                .layoutPriority(1)

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.surfaceUI)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers
private func answersTuple(from content: String) -> (String, String, String) {
    let arr = parseBlessingTallyBody(content)
    let a0 = arr.indices.contains(0) ? arr[0] : ""
    let a1 = arr.indices.contains(1) ? arr[1] : ""
    let a2 = arr.indices.contains(2) ? arr[2] : ""
    return (a0, a1, a2)
}
