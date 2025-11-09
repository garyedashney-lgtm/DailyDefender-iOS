import SwiftUI

// MARK: - Local short date helpers
private func dateOnlyLabel(_ date: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "EEE, MMM d, yyyy"
    return f.string(from: date)
}

private struct CreatedUpdatedRowCompact: View {
    let created: Date
    let updated: Date
    var body: some View {
        HStack(spacing: 10) {
            Text("Created \(dateOnlyLabel(created))")
                .font(.caption)
                .foregroundStyle(AppTheme.textPrimary)
            Text("•")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Text("Updated \(dateOnlyLabel(updated))")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
        }
    }
}

// MARK: - One TenR section (header + optional prompt + input)
private struct TenRSectionCard: View {
    let index: Int
    let title: String
    let prompt: String?
    @Binding var text: String
    let isEditing: Bool
    let showInput: Bool   // steps 1..9 = true, step 10 = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header style per your preference (smaller + dimmer)
            Text("\(index + 1) — \(title)")
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)

            if let p = prompt, !p.isEmpty {
                Text(p)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showInput {
                ZStack(alignment: .topLeading) {
                    if isEditing && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Your response…")
                            .font(.callout)
                            .foregroundStyle(Color(uiColor: .placeholderText))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 110, alignment: .topLeading)
                        .disabled(!isEditing)
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.surfaceUI))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.textSecondary.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - TenR Editor
struct TenREditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: HabitStore

    // Entry state
    @State private var createdAt: Date
    @State private var updatedAt: Date
    @State private var titleText: String
    @State private var answers: [String]          // size = TenR.inputCount (1..9)
    @State private var isEditingExisting: Bool
    @State private var isEditing: Bool
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    // Toolbar actions
    @State private var showJournalShield = false
    @State private var showProfileEdit = false
    private let shieldAsset = "AppShieldSquare"

    // Callbacks
    var onBack: () -> Void = {}
    var onSave: (_ title: String, _ body: String, _ createdAt: Date) -> Void = { _,_,_ in }
    var onDelete: () -> Void = {}

    init(
        initialTitle: String = "10R Process",
        initialCreatedAt: Date = Date(),
        initialUpdatedAt: Date? = nil,
        initialAnswers: [String] = Array(repeating: "", count: max(1, (TenR.inputCount))), // 9 inputs
        isEditingExisting: Bool = false,
        onBack: @escaping () -> Void = {},
        onSave: @escaping (_ title: String, _ body: String, _ createdAt: Date) -> Void = { _,_,_ in },
        onDelete: @escaping () -> Void = {}
    ) {
        _titleText = State(initialValue: initialTitle)
        _createdAt = State(initialValue: initialCreatedAt)
        _updatedAt = State(initialValue: initialUpdatedAt ?? initialCreatedAt)
        // ensure exactly TenR.inputCount slots
        let trimmed = Array(initialAnswers.prefix(TenR.inputCount)) + Array(repeating: "", count: max(0, TenR.inputCount - initialAnswers.count))
        _answers = State(initialValue: trimmed)
        _isEditingExisting = State(initialValue: isEditingExisting)
        _isEditing = State(initialValue: !isEditingExisting)
        self.onBack = onBack
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    CreatedUpdatedRowCompact(created: createdAt, updated: updatedAt)

                    // Title
                    TextField("Title", text: $titleText, axis: .vertical)
                        .disabled(!isEditing)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.surfaceUI))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.textSecondary.opacity(0.15), lineWidth: 1))
                        .foregroundStyle(AppTheme.textPrimary)

                    // Sections 1..10 (inputs for 1..9)
                    ForEach(0..<TenR.titles.count, id: \.self) { i in
                        TenRSectionCard(
                            index: i,
                            title: TenR.titles[i],
                            prompt: TenR.prompts.indices.contains(i) ? TenR.prompts[i] : nil,
                            text: Binding(
                                get: { i < TenR.inputCount ? answers[i] : "" },
                                set: { newValue in
                                    if i < TenR.inputCount { answers[i] = newValue }
                                }
                            ),
                            isEditing: isEditing,
                            showInput: i < TenR.inputCount
                        )
                    }

                    // Actions
                    HStack(spacing: 40) {
                        if isEditing {
                            Button {
                                guard !isSaving else { return }
                                isSaving = true
                                let cleanTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? "10R Process"
                                    : titleText.trimmingCharacters(in: .whitespacesAndNewlines)
                                // Build body (answers 1..9; step 10 rendered as informational by builder)
                                let body = buildTenRBody(answers)
                                onSave(cleanTitle, body, createdAt)
                                dismiss()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Save")
                                }
                                .font(.title3.weight(.semibold))
                                .frame(height: 42)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.appGreen)
                            .foregroundColor(.white)
                            .disabled(isSaving)
                            .buttonBorderShape(.roundedRectangle(radius: 12))
                        } else {
                            Button {
                                isEditing = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "pencil")
                                    Text("Edit")
                                }
                                .font(.title3.weight(.semibold))
                                .frame(height: 42)
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.white)
                            .buttonBorderShape(.roundedRectangle(radius: 12))
                        }

                        Button {
                            onBack()
                            dismiss()
                        } label: {
                            Text("Back")
                                .font(.title3.weight(.semibold))
                                .frame(height: 42)
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.white)
                        .buttonBorderShape(.roundedRectangle(radius: 12))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)

                    // Delete (existing only)
                    HStack {
                        Spacer()
                        if isEditingExisting {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Image(systemName: "trash").foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 6)
                            .alert("Delete entry?", isPresented: $showDeleteConfirm) {
                                Button("Cancel", role: .cancel) {}
                                Button("Delete", role: .destructive) {
                                    onDelete()
                                    dismiss()
                                }
                            } message: {
                                Text("This will permanently delete this journal entry.")
                            }
                        }
                    }

                    Spacer(minLength: 56)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        // Toolbar
        .toolbar {
            // LEFT — Brand / Shield icon (tappable)
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showJournalShield = true }) {
                    (UIImage(named: shieldAsset) != nil
                     ? Image(shieldAsset).resizable().scaledToFit()
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
                Text("10R Process")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.bottom, 10)
            }

            // RIGHT — Profile avatar (tappable)
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
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(AppTheme.navy900, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 48) }

        // Presentations
        .fullScreenCover(isPresented: $showJournalShield) {
            ShieldPage(
                imageName: (UIImage(named: shieldAsset) != nil ? shieldAsset : "AppShieldSquare")
            )
        }
        .sheet(isPresented: $showProfileEdit) {
            ProfileEditView().environmentObject(store)
        }

        // Footer re-tap → pop
        .onReceive(NotificationCenter.default.publisher(for: .JumpToJournalHome)) { _ in
            dismiss()
        }
    }
}
