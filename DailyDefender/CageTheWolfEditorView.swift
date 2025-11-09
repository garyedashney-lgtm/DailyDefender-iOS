import SwiftUI
import UIKit

// MARK: - Local auto-growing UITextView (scoped to this file)
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

// MARK: - Small date row (local)
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

// MARK: - One CTW section (header + optional prompt + editor)
private struct CtwSectionCard: View {
    let header: String
    let prompt: String?
    @Binding var text: String
    let isEditable: Bool
    @State private var height: CGFloat = 140

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Your preferred header style (smaller + dimmer)
            Text(header)
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)

            if let prompt, !prompt.isEmpty {
                Text(prompt)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.9))
            }

            ZstackEditor
        }
    }

    @ViewBuilder
    private var ZstackEditor: some View {
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

// MARK: - CageTheWolfEditorView
struct CageTheWolfEditorView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    // State
    @State private var createdAt: Date
    @State private var updatedAt: Date
    @State private var titleText: String
    @State private var answers: [String]          // only for sections 1–5
    @State private var isEditingExisting: Bool
    @State private var isEditing: Bool
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    // Toolbar presentation state
    @State private var showJournalShield = false
    @State private var showProfileEdit = false

    // Callbacks
    var onBack: () -> Void = {}
    var onSave: (_ title: String, _ body: String, _ createdAt: Date) -> Void = { _,_,_ in }
    var onDelete: () -> Void = {}

    private let shieldAsset = "AppShieldSquare"

    init(
        initialTitle: String = Ctw.title,
        initialCreatedAt: Date = Date(),
        initialUpdatedAt: Date? = nil,
        initialAnswers: [String] = Array(repeating: "", count: Ctw.inputCount),
        isEditingExisting: Bool = false,
        onBack: @escaping () -> Void = {},
        onSave: @escaping (_ title: String, _ body: String, _ createdAt: Date) -> Void = { _,_,_ in },
        onDelete: @escaping () -> Void = {}
    ) {
        _titleText = State(initialValue: initialTitle)
        _createdAt = State(initialValue: initialCreatedAt)
        _updatedAt = State(initialValue: initialUpdatedAt ?? initialCreatedAt)
        // normalize to exactly 5 inputs
        let normalized = initialAnswers.count >= Ctw.inputCount
            ? Array(initialAnswers.prefix(Ctw.inputCount))
            : initialAnswers + Array(repeating: "", count: Ctw.inputCount - initialAnswers.count)
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
                VStack(alignment: .leading, spacing: 14) {
                    CreatedUpdatedRowCompact(created: createdAt, updated: updatedAt)

                    // Title (non-outlined, same style as 3B)
                    TextField("Title", text: $titleText, axis: .vertical)
                        .disabled(!isEditing)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.surfaceUI))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.textSecondary.opacity(0.15), lineWidth: 1))
                        .foregroundStyle(AppTheme.textPrimary)

                    // Sections 1..5 editable, 6 informational
                    ForEach(0..<Ctw.sectionCount, id: \.self) { i in
                        if i < Ctw.inputCount {
                            CtwSectionCard(
                                header: "\(i + 1) — \(Ctw.titles[i])",
                                prompt: Ctw.prompts[i].isEmpty ? nil : Ctw.prompts[i],
                                text: $answers[i],
                                isEditable: isEditing
                            )
                        } else {
                            // Section 6 (informational with link)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(i + 1) — \(Ctw.titles[i])")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)

                                Text("Repeat sequences as needed. For more on Cage The Wolf, tap the link below:")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary.opacity(0.9))

                                Link("Click here",
                                     destination: URL(string: "https://www.amazon.com/SIPPING-FEAR-PISSING-CONFIDENCE-Addictions/dp/198795405X/ref=tmm_pap_swatch_0")!)
                                    .font(.body.weight(.semibold))
                            }
                        }
                    }

                    // Actions
                    HStack(spacing: 40) {
                        if isEditing {
                            Button {
                                guard !isSaving else { return }
                                isSaving = true
                                let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Ctw.title
                                    : titleText.trimmingCharacters(in: .whitespacesAndNewlines)

                                // Build 6 blocks: first 5 from answers, last empty (informational)
                                var blocks = answers
                                if blocks.count < Ctw.inputCount {
                                    blocks += Array(repeating: "", count: Ctw.inputCount - blocks.count)
                                }
                                blocks += [""] // section 6 placeholder
                                let body = buildCtwBody(blocks)

                                onSave(title, body, createdAt)
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
                    (UIImage(named: shieldAsset) != nil ? Image(shieldAsset).resizable().scaledToFit()
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
                Text("Cage The Wolf")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.bottom, 10)
            }
            // RIGHT — Profile avatar (tappable)
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
