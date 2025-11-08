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
        case search
    }
    @State private var path: [JournalRoute] = []

    // Optional external callbacks (wire as you build editors)
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

                            // 📓 Free Flow — – Talk!
                            JournalCardRow(
                                title: "Free Flow",
                                subtitle: "– Talk!",
                                emoji: "📓"
                            ) {
                                path.append(.freeFlowNew)
                                onFreeFlow()
                            }

                            // 🙏 Gratitude — – Thanks!
                            JournalCardRow(
                                title: "Gratitude",
                                subtitle: "– Thanks!",
                                emoji: "🙏"
                            ) {
                                path.append(.gratitudeNew)
                                onGratitude()
                            }

                            // ✨ 3 Blessings — – Tally!
                            JournalCardRow(
                                title: "3 Blessings",
                                subtitle: "– Tally!",
                                emoji: "✨"
                            ) {
                                path.append(.blessingTallyNew)
                                onBlessingTally()
                            }

                            // 🐺 Cage The Wolf — – Tempted?
                            JournalCardRow(
                                title: "Cage The Wolf",
                                subtitle: "– Tempted?",
                                emoji: "🐺",
                                action: onCageTheWolf
                            )

                            // 📝 10R Process — – Triggered?
                            JournalCardRow(
                                title: "10R Process",
                                subtitle: "– Triggered?",
                                emoji: "📝",
                                action: onTenR
                            )

                            // 🪞 Self Care Writing — – Traumatized?
                            JournalCardRow(
                                title: "Self Care Writing",
                                subtitle: "– Traumatized?",
                                emoji: "🪞",
                                action: onSelfCareWriting
                            )

                            // --- Section: Journal Library ---
                            SectionHeaderCustom(title: "Journal Library", emoji: "📚")

                            // 🔍 Search
                            JournalCardRow(
                                title: "Journal Library Search",
                                emoji: "🔍"
                            ) {
                                path.append(.search)
                                onSearch()
                            }

                            // Helper row
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
                    // LEFT — Brand / Shield icon
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showJournalShield = true }) {
                            (UIImage(named: journalShieldAsset) != nil
                             ? Image(journalShieldAsset).resizable().scaledToFit()
                             : Image("AppShieldSquare").resizable().scaledToFit()
                            )
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppTheme.textSecondary.opacity(0.4), lineWidth: 1))
                            .padding(4)
                            .offset(y: -2)
                        }
                        .accessibilityLabel("Open Journal shield")
                    }

                    // CENTER — Title
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 6) {
                            Text("Journal")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        .padding(.bottom, 10)
                    }

                    // RIGHT — Profile avatar
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
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 48) }

                // 🔔 Jump back to JournalHome when footer Journal is re-tapped
                .onReceive(NotificationCenter.default.publisher(for: .JumpToJournalHome)) { _ in
                    path = []   // pop to root of Journal stack
                }

                // Shield full-screen
                .fullScreenCover(isPresented: $showJournalShield) {
                    ShieldPage(
                        imageName: (UIImage(named: journalShieldAsset) != nil
                                    ? journalShieldAsset
                                    : "AppShieldSquare")
                    )
                }

                // Profile sheet
                .sheet(isPresented: $showProfileEdit) {
                    ProfileEditView().environmentObject(store)
                }

                // === Destinations ===
                .navigationDestination(for: JournalRoute.self) { route in
                    switch route {

                    case .freeFlowNew:
                        FreeFlowEditorView(
                            initialTitle: "",
                            initialBody: "",
                            initialCreatedAt: Date(),
                            initialUpdatedAt: nil,
                            isEditingExisting: false,
                            onBack: { dismiss() },
                            onSave: { title, body, created in
                                JournalMemoryStore.shared.addFreeFlow(title: title, body: body, createdAt: created)
                                dismiss()
                            },
                            onDelete: { }
                        )
                        .environmentObject(store)
                        .onReceive(NotificationCenter.default.publisher(for: .JumpToJournalHome)) { _ in
                            dismiss()
                        }

                    case .freeFlowExisting(let entry):
                        FreeFlowEditorView(
                            initialTitle: entry.title,
                            initialBody: entry.content,
                            initialCreatedAt: Date(timeIntervalSince1970: TimeInterval(entry.dateMillis) / 1000),
                            initialUpdatedAt: Date(timeIntervalSince1970: TimeInterval(entry.updatedAt) / 1000),
                            isEditingExisting: true,
                            onBack: { dismiss() },
                            onSave: { title, body, created in
                                JournalMemoryStore.shared.updateEntry(
                                    id: entry.id,
                                    title: title,
                                    body: body,
                                    createdAt: created
                                )
                                dismiss()
                            },
                            onDelete: {
                                JournalMemoryStore.shared.delete(ids: [entry.id])
                                dismiss()
                            }
                        )
                        .environmentObject(store)
                        .onReceive(NotificationCenter.default.publisher(for: .JumpToJournalHome)) { _ in
                            dismiss()
                        }

                    case .blessingTallyNew:
                        BlessingTallyEditorView(
                            initialTitle: "3 Blessings",
                            initialCreatedAt: Date(),
                            initialAnswers: ("", "", ""), // keep your tuple seed; editor builds body internally
                            isEditingExisting: false,
                            onBack: { dismiss() },
                            onSave: { title, body, created in
                                // 'body' is already the combined 3B text from the editor
                                JournalMemoryStore.shared.addFreeFlow(title: title, body: body, createdAt: created)
                                dismiss()
                            },
                            onDelete: { }
                        )
                        .environmentObject(store)
                        .onReceive(NotificationCenter.default.publisher(for: .JumpToJournalHome)) { _ in
                            dismiss()
                        }

                    case .blessingTallyExisting(let entry):
                        BlessingTallyEditorView(
                            initialTitle: entry.title.isEmpty ? "3 Blessings" : entry.title,
                            initialCreatedAt: Date(timeIntervalSince1970: TimeInterval(entry.dateMillis) / 1000),
                            initialAnswers: answersTuple(from: entry.content),
                            isEditingExisting: true,
                            onBack: { dismiss() },
                            onSave: { title, body, created in
                                JournalMemoryStore.shared.updateEntry(
                                    id: entry.id,
                                    title: title,
                                    body: body,
                                    createdAt: created
                                )
                                dismiss()
                            },
                            onDelete: {
                                JournalMemoryStore.shared.delete(ids: [entry.id])
                                dismiss()
                            }
                        )
                        .environmentObject(store)
                        .onReceive(NotificationCenter.default.publisher(for: .JumpToJournalHome)) { _ in
                            dismiss()
                        }
                        
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
                            onDelete: { }
                        )
                        .environmentObject(store)
                        
                    case .search:
                        JournalLibrarySearchView(
                            allEntries: journalStore.entries,
                            onOpen: { tapped in
                                // Route to Blessing Tally editor if it matches; else Free Flow
                                if looksLikeBlessingTallyLocal(tapped.content) {
                                    path.append(.blessingTallyExisting(tapped))
                                } else {
                                    path.append(.freeFlowExisting(tapped))
                                }
                            },
                            onDelete: { ids in JournalMemoryStore.shared.delete(ids: ids) }
                        )
                        .environmentObject(store)
                        .onReceive(NotificationCenter.default.publisher(for: .JumpToJournalHome)) { _ in
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Local detector used for routing from Library
private func looksLikeBlessingTallyLocal(_ content: String) -> Bool {
    let pattern = #"(?m)^\s*1\s*[—-]\s*What are three things from today that went well\.?"#
    return content.range(of: pattern, options: .regularExpression) != nil
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

                // Inline title + subtitle (Android parity)
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
private func answersTuple(from content: String) -> (String, String, String) {
    let arr = parseBlessingTallyBody(content)
    let a0 = arr.indices.contains(0) ? arr[0] : ""
    let a1 = arr.indices.contains(1) ? arr[1] : ""
    let a2 = arr.indices.contains(2) ? arr[2] : ""
    return (a0, a1, a2)
}
