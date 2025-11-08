import SwiftUI
import UIKit

// MARK: - Auto-growing UIKit text view (no internal scroll)
private struct AutoGrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var calculatedHeight: CGFloat
    var isEditable: Bool
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var textColor: UIColor = .white
    var tint: UIColor = UIColor(AppTheme.appGreen)
    var contentInset: UIEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

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
        tv.textContainerInset = contentInset
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.delegate = context.coordinator
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
        uiView.isEditable = isEditable
        uiView.font = font
        uiView.textColor = textColor
        uiView.tintColor = tint
        uiView.textContainerInset = contentInset
        AutoGrowingTextView.recalculateHeight(view: uiView, result: $calculatedHeight)
    }

    static func recalculateHeight(view: UIView, result: Binding<CGFloat>) {
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
            AutoGrowingTextView.recalculateHeight(view: textView, result: parent.$calculatedHeight)
        }
    }
}

// MARK: - Compact Created/Updated row (Android parity)
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

// MARK: - One section (header + editor)
private struct BlessingSectionCard: View {
    let header: String
    @Binding var text: String
    var isEditing: Bool

    @State private var height: CGFloat = 140

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(header)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            ZStack(alignment: .topLeading) {
                if isEditing && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Your thoughts")
                        .font(.callout)
                        .foregroundStyle(Color(uiColor: .placeholderText))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }

                if isEditing {
                    AutoGrowingTextView(text: $text, calculatedHeight: $height, isEditable: true)
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

// MARK: - BlessingTallyEditorView
struct BlessingTallyEditorView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    // Entry state
    @State private var createdAt: Date
    @State private var updatedAt: Date
    @State private var titleText: String
    @State private var a1: String
    @State private var a2: String
    @State private var a3: String
    @State private var isEditingExisting: Bool
    @State private var isEditing: Bool
    @State private var isSaving = false

    // Delete confirm
    @State private var showDeleteConfirm = false

    // Callbacks
    var onBack: () -> Void = {}
    var onSave: (_ title: String, _ body: String, _ createdAt: Date) -> Void = { _,_,_ in }
    var onDelete: () -> Void = {}

    private let shieldAsset = "AppShieldSquare"

    init(
        initialTitle: String = BlessingTally.title,
        initialCreatedAt: Date = Date(),
        initialUpdatedAt: Date? = nil,
        initialAnswers: (String, String, String) = ("", "", ""),
        isEditingExisting: Bool = false,
        onBack: @escaping () -> Void = {},
        onSave: @escaping (_ title: String, _ body: String, _ createdAt: Date) -> Void = { _,_,_ in },
        onDelete: @escaping () -> Void = {}
    ) {
        _titleText = State(initialValue: initialTitle)
        _createdAt = State(initialValue: initialCreatedAt)
        _updatedAt = State(initialValue: initialUpdatedAt ?? initialCreatedAt)
        _a1 = State(initialValue: initialAnswers.0)
        _a2 = State(initialValue: initialAnswers.1)
        _a3 = State(initialValue: initialAnswers.2)
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

                    // Tip (per Android)
                    Text("Tip: Try this for 7 days and then adopt the practice for life...")
                        .font(.callout.italic())
                        .foregroundStyle(AppTheme.textSecondary)

                    // Sections (1–3)
                    BlessingSectionCard(header: BlessingTally.sections[0], text: $a1, isEditing: isEditing)
                    BlessingSectionCard(header: BlessingTally.sections[1], text: $a2, isEditing: isEditing)
                    BlessingSectionCard(header: BlessingTally.sections[2], text: $a3, isEditing: isEditing)

                    // Actions
                    HStack(spacing: 40) {
                        if isEditing {
                            Button {
                                guard !isSaving else { return }
                                isSaving = true
                                let trimmedTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? BlessingTally.title
                                    : titleText.trimmingCharacters(in: .whitespacesAndNewlines)
                                let body = buildBlessingTallyBody([a1, a2, a3])
                                onSave(trimmedTitle, body, createdAt)
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
            ToolbarItem(placement: .navigationBarLeading) {
                (UIImage(named: shieldAsset) != nil ? Image(shieldAsset).resizable().scaledToFit()
                                                    : Image("AppShieldSquare").resizable().scaledToFit())
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.textSecondary.opacity(0.4), lineWidth: 1))
                    .padding(4)
                    .offset(y: -2)
            }
            ToolbarItem(placement: .principal) {
                Text("3 Blessings")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
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
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(AppTheme.navy900, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 48) }

        // Footer re-tap → pop
        .onReceive(NotificationCenter.default.publisher(for: .JumpToJournalHome)) { _ in
            dismiss()
        }
    }
}
