import SwiftUI
import UIKit

// MARK: - A tiny UIKit-backed text view so we can place the caret
private struct SeedableTextView: UIViewRepresentable {
    @Binding var text: String
    var isEditable: Bool
    var moveCursorToEnd: Bool   // when true, we set selectedRange to end (one-shot)
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var textColor: UIColor = .white
    var tint: UIColor = UIColor(AppTheme.appGreen)
    var inset: UIEdgeInsets = .init(top: 8, left: 8, bottom: 8, right: 8)

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.isScrollEnabled = true
        tv.alwaysBounceVertical = true
        tv.isEditable = isEditable
        tv.isSelectable = true
        tv.text = text
        tv.font = font
        tv.textColor = textColor
        tv.tintColor = tint
        tv.textContainerInset = inset
        tv.textContainer.lineFragmentPadding = 0
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

        // Move caret to end once when requested
        if moveCursorToEnd {
            let end = (ui.text as NSString).length
            ui.selectedRange = NSRange(location: end, length: 0)
            // Also scroll to caret if content is long
            ui.scrollRangeToVisible(ui.selectedRange)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SeedableTextView
        init(_ parent: SeedableTextView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}

// MARK: - Simple date labels (compact, like other editors)
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

// MARK: - Gratitude Editor
struct GratitudeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: HabitStore

    // Public callbacks (match your existing signature)
    var onBack: () -> Void = {}
    var onSave: (_ title: String, _ body: String, _ createdAt: Date) -> Void = { _,_,_ in }
    var onDelete: () -> Void = {}

    // State
    @State private var createdAt: Date
    @State private var updatedAt: Date
    @State private var titleText: String
    @State private var bodyText: String
    @State private var isEditingExisting: Bool
    @State private var isEditing: Bool
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    // One-shot flag to place cursor at end after seeding
    @State private var shouldMoveCursorToEnd = false

    private let shieldAsset = "AppShieldSquare"
    private let gratitudeSeed = "Today, I am grateful for: "

    // Init mirrors how you construct in JournalHomeView
    init(
        initialTitle: String = "Gratitude",
        initialBody: String = "",
        initialCreatedAt: Date = Date(),
        initialUpdatedAt: Date? = nil,
        isEditingExisting: Bool = false,
        onBack: @escaping () -> Void = {},
        onSave: @escaping (_ title: String, _ body: String, _ createdAt: Date) -> Void = { _,_,_ in },
        onDelete: @escaping () -> Void = {}
    ) {
        _titleText = State(initialValue: initialTitle)
        _createdAt = State(initialValue: initialCreatedAt)
        _updatedAt = State(initialValue: initialUpdatedAt ?? initialCreatedAt)

        // Seed only for new entries with truly empty body
        if !isEditingExisting && initialBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _bodyText = State(initialValue: gratitudeSeed)
            _shouldMoveCursorToEnd = State(initialValue: true) // position caret after seed
        } else {
            _bodyText = State(initialValue: initialBody)
            _shouldMoveCursorToEnd = State(initialValue: false)
        }

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

                    // Body (seed is REAL text; we move caret after seed one time)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Journal")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)

                        SeedableTextView(
                            text: $bodyText,
                            isEditable: isEditing,
                            moveCursorToEnd: shouldMoveCursorToEnd
                        )
                        .frame(minHeight: 160)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.surfaceUI))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.textSecondary.opacity(0.15), lineWidth: 1))
                        .onAppear {
                            // Ensure we only try to move once
                            if shouldMoveCursorToEnd { DispatchQueue.main.async { shouldMoveCursorToEnd = false } }
                        }
                    }

                    // Actions
                    HStack(spacing: 40) {
                        if isEditing {
                            Button {
                                guard !isSaving else { return }
                                isSaving = true
                                let cleanTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? "Gratitude"
                                    : titleText.trimmingCharacters(in: .whitespacesAndNewlines)
                                // No stripping of the seed — it's intentional real content.
                                onSave(cleanTitle, bodyText, createdAt)
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
                Text("Gratitude")
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

        .onReceive(NotificationCenter.default.publisher(for: .JumpToJournalHome)) { _ in
            dismiss()
        }
    }
}
