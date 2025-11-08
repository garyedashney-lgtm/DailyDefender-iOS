import SwiftUI
import UIKit

// MARK: - Auto-growing UIKit text view (expands with content, no internal scroll)
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

// MARK: - Body editor card (split out to help the compiler)
private struct BodyCardView: View {
    @Binding var bodyText: String
    @Binding var editorHeight: CGFloat
    var isEditing: Bool
    var systemPlaceholder: Color
    var minLines: Int = 5   // 👈 new

    private var minHeight: CGFloat {
        // Use system body font line height × lines + padding
        let lh = UIFont.preferredFont(forTextStyle: .body).lineHeight
        // +20 approximates your inner/top-bottom padding inside the card
        return ceil(lh * CGFloat(max(1, minLines))) + 20
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if isEditing {
                if bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Your thoughts")
                        .font(.callout)
                        .foregroundColor(systemPlaceholder)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                AutoGrowingTextView(
                    text: $bodyText,
                    calculatedHeight: $editorHeight,
                    isEditable: true
                )
                // 👇 ensure at least ~5 lines tall on first render
                .frame(height: max(editorHeight, minHeight), alignment: .topLeading)
            } else {
                Text(bodyText.isEmpty ? "—" : bodyText)
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
// MARK: - FreeFlowEditorView
struct FreeFlowEditorView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    // Header actions
    @State private var showShield = false
    @State private var showProfileEdit = false

    // Entry state
    @State private var createdAt: Date
    @State private var updatedAt: Date
    @State private var titleText: String
    @State private var bodyText: String
    @State private var isEditingExisting: Bool
    @State private var isEditing: Bool
    @State private var isSaving: Bool = false

    // Delete confirm
    @State private var showDeleteConfirm = false

    // Auto-growing editor height
    @State private var editorHeight: CGFloat = 180

    // Callbacks
    var onBack: () -> Void = {}
    var onSave: (_ title: String, _ body: String, _ createdAt: Date) -> Void = { _,_,_ in }
    var onDelete: () -> Void = {}

    private let shieldAsset = "AppShieldSquare"
    private var systemPlaceholder: Color { Color(uiColor: .placeholderText) }

    init(
        initialTitle: String = "",
        initialBody: String = "",
        initialCreatedAt: Date = Date(),
        initialUpdatedAt: Date? = nil,   // 👈 NEW (defaults to createdAt when nil)
        isEditingExisting: Bool = false,
        onBack: @escaping () -> Void = {},
        onSave: @escaping (_ title: String, _ body: String, _ createdAt: Date) -> Void = { _,_,_ in },
        onDelete: @escaping () -> Void = {}
    ) {
        _createdAt = State(initialValue: initialCreatedAt)
        _updatedAt = State(initialValue: initialUpdatedAt ?? initialCreatedAt) // 👈 NEW
        _titleText = State(initialValue: initialTitle)
        _bodyText = State(initialValue: initialBody)
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
                    HStack(spacing: 8) {
                        Text("Created \(dateLabel(createdAt))")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text("Updated \(dateLabel(updatedAt))")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary) // muted like Android's onSurfaceVariant
                    }
                    .padding(.top, 2)

                    // Title
                    TextField("Title", text: $titleText, axis: .vertical)
                        .disabled(!isEditing)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.surfaceUI))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.textSecondary.opacity(0.15), lineWidth: 1))
                        .foregroundStyle(AppTheme.textPrimary)

                    // Body (split view)
                    BodyCardView(
                        bodyText: $bodyText,
                        editorHeight: $editorHeight,
                        isEditing: isEditing,
                        systemPlaceholder: systemPlaceholder
                    )

                    // Actions — centered, spaced
                    HStack(spacing: 40) {
                        if isEditing {
                            Button {
                                guard !isSaving else { return }
                                isSaving = true
                                dismissKeyboard()
                                let trimmed = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
                                updatedAt = Date() // 👈 reflect the new update time in UI (store also updates)
                                onSave(trimmed, bodyText, createdAt)
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
                                // when switching to edit, keep the current expanded height
                                editorHeight = computeEditorHeight(for: bodyText)
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
                            dismissKeyboard()
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

                    // Delete (existing only) with confirmation
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
        // Header
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showShield = true }) {
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

            ToolbarItem(placement: .principal) {
                Text("New Entry")
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

        // Footer re-tap (Journal) → pop
        .onReceive(NotificationCenter.default.publisher(for: .JumpToJournalHome)) { _ in
            dismiss()
        }

        // Covers / sheets
        .fullScreenCover(isPresented: $showShield) {
            ShieldPage(imageName: (UIImage(named: shieldAsset) != nil ? shieldAsset : "AppShieldSquare"))
        }
        .sheet(isPresented: $showProfileEdit) {
            ProfileEditView().environmentObject(store)
        }
    }

    // MARK: - Helpers

    private func computeEditorHeight(for text: String) -> CGFloat {
        let outerPadding: CGFloat = 16 * 2
        let innerPadding: CGFloat = 12 * 2
        let availableWidth: CGFloat = UIScreen.main.bounds.width - outerPadding - innerPadding
        let string: NSString = (text.isEmpty ? " " : text) as NSString
        let font = UIFont.preferredFont(forTextStyle: .body)
        let maxSize = CGSize(width: availableWidth, height: .greatestFiniteMagnitude)
        let rect = string.boundingRect(
            with: maxSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        let base = ceil(rect.height) + 20 // padding inside the card
        return max(180, base)
    }

    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d, yyyy"
        return f.string(from: date)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
