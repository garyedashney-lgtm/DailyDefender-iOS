import SwiftUI

// MARK: - Section Headers

struct SectionHeader: View {
    let label: String
    let pillar: Pillar
    let countText: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(pillar.emoji)
                .font(.body)

            Text(label)
                .font(.body.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)

            Rectangle()
                .frame(height: 1)
                .foregroundStyle(AppTheme.divider)

            if let t = countText {
                Text(t)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.appGreen)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .textCase(nil)
    }
}

// MARK: - Avatar

struct AvatarView: View {
    let name: String
    let photoPath: String?
    let size: CGFloat
    let onTap: (() -> Void)?

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let inits = parts.map { String($0.prefix(1)).uppercased() }.joined()
        return inits.isEmpty ? "?" : inits
    }

    var body: some View {
        Group {
            if let path = photoPath, let ui = UIImage(contentsOfFile: path) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(AppTheme.navy900)
                    Text(initials)
                        .foregroundStyle(.white)
                        .font(.system(size: size * 0.42, weight: .bold))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(AppTheme.divider, lineWidth: 1)
        )
        .contentShape(Circle())
        .onTapGesture { onTap?() }
    }
}

// MARK: - Habit Row

struct HabitRow: View {
    let habit: Habit
    let checked: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        checked ? .white : AppTheme.textPrimary,
                        checked ? AppTheme.appGreen : .clear
                    )
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.title)
                        .font(.body)
                        .fontWeight(habit.isCore ? .bold : .regular)
                        .foregroundStyle(AppTheme.textPrimary)
                    if let sub = habit.subtitle {
                        Text(sub)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(AppTheme.surfaceCard, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - App Header (Toolbar .principal content)

struct AppHeaderBar: View {
    // Center content
    let title: String
    var subtitle: String? = nil
    var centerEmoji: String? = nil
    var centerSymbol: String? = nil

    // Sides
    var appLogoName: String = "AppShieldSquare"
    var profileAsset: String? = nil
    var onLeftTap: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // LEFT / RIGHT
            HStack {
                Image(appLogoName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .padding(4)
                    .contentShape(Rectangle())
                    .onTapGesture { onLeftTap?() }
                    .accessibilityLabel("Open Brand Shield")

                Spacer()

                Group {
                    if let p = profileAsset, UIImage(named: p) != nil {
                        Image(p).resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, AppTheme.appGreen)
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
            }

            // CENTER: icon + title + optional subtitle
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    if let e = centerEmoji, !e.isEmpty {
                        Text(e).font(.title2)
                    } else if let s = centerSymbol, !s.isEmpty {
                        Image(systemName: s)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(AppTheme.appGreen, .white)
                            .font(.title2)
                    }
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                }
                if let sub = subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.bottom, 6)
                }
            }
        }
    }
}

// MARK: - Modifier + convenience

struct AppHeaderModifier: ViewModifier {
    let title: String
    var subtitle: String? = nil
    var centerEmoji: String? = nil
    var centerSymbol: String? = nil
    var appLogoName: String = "AppShieldSquare"
    var profileAsset: String? = nil
    var onLeftTap: (() -> Void)? = nil

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .principal) {
                    AppHeaderBar(
                        title: title,
                        subtitle: subtitle,
                        centerEmoji: centerEmoji,
                        centerSymbol: centerSymbol,
                        appLogoName: appLogoName,
                        profileAsset: profileAsset,
                        onLeftTap: onLeftTap
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(AppTheme.navy900, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

extension View {
    func appHeader(
        title: String,
        subtitle: String? = nil,
        centerEmoji: String? = nil,
        centerSymbol: String? = nil,
        appLogoName: String = "AppShieldSquare",
        profileAsset: String? = nil,
        onLeftTap: (() -> Void)? = nil
    ) -> some View {
        modifier(AppHeaderModifier(
            title: title,
            subtitle: subtitle,
            centerEmoji: centerEmoji,
            centerSymbol: centerSymbol,
            appLogoName: appLogoName,
            profileAsset: profileAsset,
            onLeftTap: onLeftTap
        ))
    }
}

/// Full-width left-aligned section header with an emoji, title, and a thin divider.
/// Shared across Weekly/Resources/Info.
struct EmojiSectionHeader: View {
    let label: String
    let emoji: String
    var body: some View {
        HStack(spacing: 8) {
            Text(emoji).font(.body)
            Text(label)
                .font(.body.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(AppTheme.divider)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}

// MARK: - One-time auto-focus helper (per screen)

@MainActor
struct AutoFocusOnceModifier<F: Hashable>: ViewModifier {
    @Binding var didAutoFocus: Bool
    let focus: FocusState<F?>.Binding
    let field: F
    let delay: Double

    func body(content: Content) -> some View {
        content.onAppear {
            guard !didAutoFocus else { return }
            didAutoFocus = true
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                focus.wrappedValue = field
            }
        }
    }
}

extension View {
    /// Automatically focuses a field once when the view first appears.
    /// Usage:
    ///   enum Field { case name, email }
    ///   @FocusState var focused: Field?
    ///   @State var didAutoFocus = false
    ///   .autoFocusOnce(didAutoFocus: $didAutoFocus, focus: $focused, field: .name)
    func autoFocusOnce<F: Hashable>(
        didAutoFocus: Binding<Bool>,
        focus: FocusState<F?>.Binding,
        field: F,
        delay: Double = 0.35
    ) -> some View {
        modifier(AutoFocusOnceModifier(didAutoFocus: didAutoFocus, focus: focus, field: field, delay: delay))
    }
}

// MARK: - Reusable text field

struct DefenderTextField<F: Hashable>: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    // Focus plumbing (must pass a FocusState from parent view)
    let focus: FocusState<F?>.Binding
    let thisField: F

    // Config
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .done
    var autocapitalization: TextInputAutocapitalization = .never
    var autocorrectionDisabled: Bool = true
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(autocorrectionDisabled)
                .textContentType(contentType)
                .submitLabel(submitLabel)
                .focused(focus, equals: thisField)
                .padding(12)
                .background(AppTheme.surfaceUI, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(AppTheme.textPrimary)
                .contentShape(Rectangle()) // bigger tap target
                .onTapGesture { focus.wrappedValue = thisField }
                .onSubmit { onSubmit?() }
        }
    }
}
