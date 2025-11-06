import SwiftUI

struct JournalHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var session: SessionViewModel
    @ObservedObject private var journalStore = JournalMemoryStore.shared   // temp in-memory demo store

    // Header actions
    @State private var showJournalShield = false
    @State private var showProfileEdit = false

    // Navigation
    private enum JournalRoute: Hashable {
        case freeFlowNew
        case freeFlowExisting(JournalEntryIOS)
        case search
    }
    @State private var path: [JournalRoute] = []

    // Optional external callbacks
    var onFreeFlow: () -> Void = {}
    var onGratitude: () -> Void = {}
    var onCageTheWolf: () -> Void = {}
    var onTenR: () -> Void = {}
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

                            // FREE FLOW — navigate to new editor
                            JournalCardRow(title: "Free Flow", emoji: "📓") {
                                path.append(.freeFlowNew)
                            }

                            // Placeholders (to wire later)
                            JournalCardRow(title: "Gratitude", emoji: "🙏", action: onGratitude)
                            JournalCardRow(title: "Cage The Wolf", emoji: "🐺", action: onCageTheWolf)
                            JournalCardRow(title: "10R Process", emoji: "📝", action: onTenR)

                            // --- Section: Library ---
                            SectionHeaderCustom(title: "Journal Library", emoji: "📚")

                            // Search — navigate to Library Search screen (keeps system back arrow)
                            JournalCardRow(title: "Journal Library Search", emoji: "🔍") {
                                path.append(.search)
                            }

                            Spacer(minLength: 56)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }
                // === Toolbar/Header ===
                .toolbar {
                    // LEFT — Shield icon
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

                // === Destination(s) ===
                .navigationDestination(for: JournalRoute.self) { route in
                    switch route {
                    case .freeFlowNew:
                        FreeFlowEditorView(
                            initialTitle: "",
                            initialBody: "",
                            initialCreatedAt: Date(),
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

                    case .search:
                        JournalLibrarySearchView(
                            allEntries: journalStore.entries,
                            onOpen: { tapped in
                                // For now, route all opens to Free Flow editor.
                                // (Once Gratitude/CTW/10R editors are in, branch by type.)
                                path.append(.freeFlowExisting(tapped))
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

                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

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
