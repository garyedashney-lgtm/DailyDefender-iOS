import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    // Picker + form state
    @State private var showPicker = false
    @State private var pickerItem: PhotosPickerItem? = nil

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var draftImage: UIImage? = nil
    @State private var draftPhotoPath: String? = nil
    @State private var errorText: String? = nil
    @State private var initialized = false

    // Original snapshot (to detect changes / enable Save)
    @State private var originalName: String = ""
    @State private var originalEmail: String = ""
    @State private var originalPhotoPath: String? = nil

    // Toast
    @State private var toastMessage: String?
    @State private var showToast = false

    // Focus — MUST be at struct scope
    private enum Field: Hashable { case name, email }
    @FocusState private var focusedField: Field?
    @State private var didAutoFocus = false

    // Shield (top-left) — static full-screen page
    @State private var showShield = false

    // Dirty detection
    private var isPhotoDirty: Bool {
        if draftImage != nil { return true }
        return draftPhotoPath != originalPhotoPath
    }
    private var isDirty: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines) != originalName.trimmingCharacters(in: .whitespacesAndNewlines)
        || email.trimmingCharacters(in: .whitespacesAndNewlines) != originalEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        || isPhotoDirty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navy900.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {

                        // Avatar picker
                        Button { showPicker = true } label: {
                            AvatarChooser(image: currentAvatarImage, label: "Change Photo")
                        }
                        .buttonStyle(.plain)
                        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
                        .onChange(of: pickerItem) { newItem in
                            guard let newItem else { return }
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self),
                                   let img = UIImage(data: data) {
                                    draftImage = img.scaledDownIfNeeded(maxDimension: 1600)
                                    draftPhotoPath = nil
                                }
                            }
                        }

                        // Name
                        LabeledField(title: "Name") {
                            TextField("Your name", text: $name)
                                .textContentType(.name)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled(false)
                                .submitLabel(.done)
                                .focused($focusedField, equals: .name)
                                .padding(12)
                                .background(AppTheme.surfaceUI, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(AppTheme.textPrimary)
                                .contentShape(Rectangle())
                                .onTapGesture { focusedField = .name }
                        }

                        // Email
                        LabeledField(title: "Email") {
                            TextField("you@domain.com", text: $email)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .submitLabel(.done)
                                .focused($focusedField, equals: .email)
                                .padding(12)
                                .background(AppTheme.surfaceUI, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(AppTheme.textPrimary)
                                .contentShape(Rectangle())
                                .onTapGesture { focusedField = .email }
                                .onSubmit { saveProfile() }
                        }

                        if let err = errorText {
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        HStack(spacing: 12) {
                            Button(role: .cancel) { dismiss() } label: {
                                Text("Cancel").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.white.opacity(0.9))

                            Button { saveProfile() } label: {
                                Text(isDirty ? "Save Changes" : "No Changes")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(isDirty ? AppTheme.appGreen : .gray.opacity(0.6))
                            .foregroundStyle(.white)
                            .disabled(!isDirty)
                        }
                        .padding(.top, 4)
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.immediately)

                // Top Banner Toast overlay
                .overlay(alignment: .top) {
                    if showToast, let msg = toastMessage {
                        BannerToast(message: msg)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(10)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                                    withAnimation { showToast = false }
                                }
                            }
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(AppTheme.navy900, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                // Standardized top-left shield → opens static ShieldPage
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showShield = true }) {
                        Image("four_ps") // change per-page if needed
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .padding(4)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Open Shield")
                }
            }
        }
        // Static shield page fullscreen (no video)
        .fullScreenCover(isPresented: $showShield) {
            ShieldPage(imageName: "four_ps") // swap PNG if this screen uses a different shield
        }
        // Mailchimp toasts from the Store (for email changes)
        .onReceive(store.$lastMailchimpMessage.compactMap { $0 }) { msg in
            hideKeyboard()
            toastMessage = msg
            withAnimation { showToast = true }

            if shouldAdvance(after: msg) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    dismiss()
                }
            }
        }
        .onChange(of: showToast) { isShowing in
            if isShowing { hideKeyboard() }
        }
        .onAppear {
            if !initialized {
                let p = store.profile
                name = p.name
                email = p.email
                draftPhotoPath = p.photoPath
                originalName = p.name
                originalEmail = p.email
                originalPhotoPath = p.photoPath
                initialized = true
            }
            // Auto-focus name once when view first appears
            if !didAutoFocus {
                didAutoFocus = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    focusedField = .name
                }
            }
        }
    }

    // MARK: - Helpers

    private var currentAvatarImage: UIImage? {
        if let img = draftImage { return img }
        if let path = draftPhotoPath, let img = UIImage(contentsOfFile: path) { return img }
        return nil
    }

    private func isValidEmail(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let regex = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES[c] %@", regex).evaluate(with: t)
    }

    private func saveProfile() {
        guard isDirty else { return }

        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailChanged = originalEmail.caseInsensitiveCompare(e) != .orderedSame

        guard !n.isEmpty else {
            errorText = "Please enter your name"
            return
        }
        if emailChanged {
            guard isValidEmail(e) else {
                errorText = "Please enter a valid email"
                hideKeyboard()
                toastMessage = "Please enter a valid email"
                withAnimation { showToast = true }
                return
            }
        }
        errorText = nil

        // Persist picked image if any
        var finalPath: String? = draftPhotoPath
        if let img = draftImage, let data = img.jpegData(compressionQuality: 0.9) {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("profile_\(UUID().uuidString).jpg")
            do { try data.write(to: url, options: .atomic); finalPath = url.path } catch { /* keep old */ }
        }

        // Save locally (keep current registration flag).
        let wasRegistered = store.profile.isRegistered
        store.saveProfile(name: n, email: e, photoPath: finalPath, isRegistered: wasRegistered)

        hideKeyboard()

        // If email changed and non-empty, wait for Mailchimp toast (onReceive).
        if emailChanged && !e.isEmpty {
            // noop here; dismissal handled after MC success/pending.
        } else {
            // Name/photo-only change OR email unchanged: quick confirm + dismiss.
            toastMessage = "Saved."
            withAnimation { showToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                dismiss()
            }
        }

        // Refresh "original" snapshot so button disables after a successful save
        originalName = n
        originalEmail = e
        originalPhotoPath = finalPath
        draftImage = nil
    }

    /// Decide if Mailchimp message is "good enough" to advance.
    private func shouldAdvance(after message: String) -> Bool {
        let lower = message.lowercased()
        let okHints = [
            "subscribed","already on the list","already subscribed",
            "subscription confirmed","successfully subscribed",
            "thank you for subscribing","check your email","almost finished"
        ]
        let errorHints = [
            "invalid","failed","couldn’t","couldn't","try again",
            "too many attempts","network error"
        ]
        if errorHints.contains(where: { lower.contains($0) }) { return false }
        if okHints.contains(where: { lower.contains($0) }) { return true }
        return true
    }
}

// MARK: - Small subviews (kept tiny to help the compiler)

private struct AvatarChooser: View {
    let image: UIImage?
    let label: String
    var body: some View {
        ZStack {
            AvatarCircle(image: image, size: 120)
            Circle()
                .stroke(AppTheme.divider, lineWidth: 1)
                .frame(width: 120, height: 120)
            VStack {
                Spacer()
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.bottom, 6)
            }
            .frame(width: 120, height: 120)
        }
    }
}

private struct LabeledField<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            content()
        }
    }
}

private struct BannerToast: View {
    let message: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
            Text(message)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.surfaceUI)
        .foregroundStyle(AppTheme.textPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(radius: 6)
        .padding(.horizontal, 16)
    }
}

// Reuse avatar circle + scaler locally
private struct AvatarCircle: View {
    let image: UIImage?
    let size: CGFloat
    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img).resizable().scaledToFill()
            } else if UIImage(named: "ATMPic") != nil {
                Image("ATMPic").resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, AppTheme.appGreen)
                    .font(.system(size: size * 0.55))
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

private extension UIImage {
    func scaledDownIfNeeded(maxDimension: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        let maxSide = max(w, h)
        guard maxSide > maxDimension else { return self }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: w * scale, height: h * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
