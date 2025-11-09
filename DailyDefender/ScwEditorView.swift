import SwiftUI
import UIKit

// MARK: - Local auto-growing UITextView (no internal scroll)
private struct AutoGrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var measuredHeight: CGFloat
    var isEditable: Bool
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var textColor: UIColor = .white
    var tint: UIColor = UIColor(AppTheme.appGreen)
    var inset: UIEdgeInsets = .init(top: 8, left: 8, bottom: 8, right: 8)

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.isScrollEnabled = false
        tv.isEditable = isEditable
        tv.isSelectable = true
        tv.text = text
        tv.font = font
        tv.textColor = textColor
        tv.tintColor = tint
        tv.textContainerInset = inset
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.delegate = context.coordinator
        return tv
    }

    func updateUIView(_ ui: UITextView, context: Context) {
        if ui.text != text { ui.text = text }
        ui.isEditable = isEditable
        ui.font = font
        ui.textColor = textColor
        ui.tintColor = tint
        ui.textContainerInset = inset
        AutoGrowingTextView.recalcHeight(ui, into: $measuredHeight)
    }

    static func recalcHeight(_ view: UIView, into result: Binding<CGFloat>) {
        let size = view.sizeThatFits(CGSize(width: view.bounds.width, height: .greatestFiniteMagnitude))
        if result.wrappedValue != size.height {
            DispatchQueue.main.async { result.wrappedValue = size.height }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: AutoGrowingTextView
        init(_ parent: AutoGrowingTextView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            AutoGrowingTextView.recalcHeight(textView, into: parent.$measuredHeight)
        }
    }
}

// MARK: - Small date row
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

// MARK: - One SCW section (header + optional prompt + editor/readonly)
private struct ScwSectionCard: View {
    let index: Int
    let title: String
    let prompt: String?
    @Binding var text: String
    let isEditable: Bool
    let showInput: Bool   // true for 1..5, false for 6

    @State private var height: CGFloat = 140

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Your preferred style for question lines
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
                    if isEditable && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Your response…")
                            .font(.callout)
                            .foregroundStyle(Color(uiColor: .placeholderText))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                    }

                    if isEditable {
                        AutoGrowingTextView(text: $text, measuredHeight: $height, isEditable: true)
                            .frame(height: max(height, 110), alignment: .topLeading)
                    } else {
                        Text(text.isEmpty ? "—" : text)
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.surfaceUI))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.textSecondary.opacity(0.15), lineWidth: 1))
            }
        }
    }
}

// MARK: - SCW Editor
struct ScwEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: HabitStore

    // Entry state
    @State private var createdAt: Date
    @State private var updatedAt: Date
    @State private var titleText: String
    @State private var answers: [String]      // size = 5 (inputs for steps 1..5)
    @State private var isEditingExisting: Bool
    @State private var isEditing: Bool
    @State private var isSaving = false

    // UI
    @State private var showDeleteConfirm = false
    @State private var showJournalShield = false
    @State private var showProfileEdit = false

    // Callbacks
    var onBack: () -> Void = {}
    var onSave: (_ title: String, _ body: String, _ createdAt: Date) -> Void = { _,_,_ in }
    var onDelete: () -> Void = {}

    private let shieldAsset = "AppShieldSquare"

    init(
        initialTitle: String = "Self Care Writing",
        initialCreatedAt: Date = Date(),
        initialUpdatedAt: Date? = nil,
        initialAnswers: [String] = Array(repeating: "", count: Scw.inputCount),
        isEditingExisting: Bool = false,
        onBack: @escaping () -> Void = {},
        onSave: @escaping (_ title: String, _ body: String, _ createdAt: Date) -> Void = { _,_,_ in },
        onDelete: @escaping () -> Void = {}
    ) {
        _titleText = State(initialValue: initialTitle)
        _createdAt = State(initialValue: initialCreatedAt)
        _updatedAt = State(initialValue: initialUpdatedAt ?? initialCreatedAt)

        // Normalize to exactly Scw.inputCount (5)
        let normalized = initialAnswers.count >= Scw.inputCount
            ? Array(initialAnswers.prefix(Scw.inputCount))
            : initialAnswers + Array(repeating: "", count: Scw.inputCount - initialAnswers.count)
        _answers = State(initialValue: normalized)

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

                    // Sections 1..6 (inputs for 1..5; section 6 is informational-only)
                    ForEach(0..<Scw.titles.count, id: \.self) { i in
                        ScwSectionCard(
                            index: i,
                            title: Scw.titles[i],
                            prompt: i < Scw.prompts.count ? Scw.prompts[i] : nil,
                            text: Binding(
                                get: { i < Scw.inputCount ? answers[i] : "" },
                                set: { newValue in
                                    if i < Scw.inputCount { answers[i] = newValue }
                                }
                            ),
                            isEditable: isEditing,
                            showInput: i < Scw.inputCount
                        )
                    }

                    // Actions
                    HStack(spacing: 40) {
                        if isEditing {
                            Button {
                                guard !isSaving else { return }
                                isSaving = true
                                let cleanTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? "Self Care Writing"
                                    : titleText.trimmingCharacters(in: .whitespacesAndNewlines)

                                // Build a 6-length payload: answers[0..4] plus section 6 informational copy
                                var payload = answers
                                if payload.count < Scw.inputCount {
                                    payload += Array(repeating: "", count: Scw.inputCount - payload.count)
                                }
                                payload += [""] // placeholder for the informational section (persisted by builder)

                                let body = buildScwBody(payload)
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
        // Toolbar with working actions (no dead taps)
        .toolbar {
            // LEFT — Shield → full screen cover
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showJournalShield = true }) {
                    (UIImage(named: shieldAsset) != nil
                     ? Image(shieldAsset).resizable().scaledToFit()
                     : Image("AppShieldSquare").resizable().scaledToFit())
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
                Text("Self Care Writing")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.bottom, 10)
            }

            // RIGHT — Avatar → profile sheet
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showProfileEdit = true }) {
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
                }
                .accessibilityLabel("Profile")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(AppTheme.navy900, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 48) }

        // Working destinations for toolbar actions
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
