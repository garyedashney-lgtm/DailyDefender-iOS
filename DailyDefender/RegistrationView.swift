import SwiftUI
import PhotosUI

struct RegistrationView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    var onRegistered: () -> Void

    // Form state
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var draftImage: UIImage?
    @State private var savedPhotoPath: String?

    // UX
    @State private var errorText: String?
    @State private var toastMessage: String?
    @State private var showToast = false

    // Focus — keep at struct scope
    private enum Field: Hashable { case name, email }
    @FocusState private var focusedField: Field?
    @State private var didAutoFocus = false
    
    @State private var showShieldShowcase = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navy900.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {

                        // Avatar picker (split into small subview to help the compiler)
                        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                            AvatarChooser(image: currentAvatarImage)
                        }
                        .onChange(of: pickerItem) { newItem in
                            guard let newItem else { return }
                            Task { await loadPickedImage(from: newItem) }
                        }

                        // Name
                        LabeledField(title: "Name") {
                            TextField("Your name", text: $name)
                                .textContentType(.name)
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
                                .onSubmit { saveAndContinue() }
                        }

                        if let err = errorText {
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        Button(action: saveAndContinue) {
                            Text("Save & Continue")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.appGreen)
                        .foregroundStyle(.white)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.immediately)

                // Top Banner Toast overlay (self-contained here)
                .overlay(alignment: .top) {
                    if showToast, let msg = toastMessage {
                        BannerToast(message: msg)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(10)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                                    withAnimation { showToast = false }
                                    store.lastMailchimpMessage = nil
                                }
                            }
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle("Create your profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(AppTheme.navy900, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: BrandPage()) {
                        Image("AppLogoRound")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(AppTheme.divider, lineWidth: 1))
                            .accessibilityLabel("Brand")
                    }
                }
            }
            // Listen for Mailchimp message
            .onReceive(store.$lastMailchimpMessage.compactMap { $0 }) { msg in
                hideKeyboard()
                toastMessage = msg
                withAnimation { showToast = true }

                if shouldAdvance(after: msg) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        onRegistered()
                    }
                }
            }
            .onChange(of: showToast) { isShowing in
                if isShowing { hideKeyboard() }
            }
            .onAppear {
                // Auto-focus name once when view first appears
                if !didAutoFocus {
                    didAutoFocus = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        focusedField = .name
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var currentAvatarImage: UIImage? {
        if let draftImage { return draftImage }
        if let path = savedPhotoPath, let img = UIImage(contentsOfFile: path) { return img }
        return nil
    }

    private func isValidEmail(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        let regex = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES[c] %@", regex).evaluate(with: t)
    }

    private func loadPickedImage(from item: PhotosPickerItem) async {
        if let data = try? await item.loadTransferable(type: Data.self),
           let img = UIImage(data: data) {
            draftImage = img.scaledDownIfNeeded(maxDimension: 1600)
            savedPhotoPath = nil
        }
    }

    private func persistDraftImageIfNeeded() -> String? {
        guard let img = draftImage,
              let data = img.jpegData(compressionQuality: 0.9) else { return savedPhotoPath }
        let filename = "profile_\(UUID().uuidString).jpg"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            return savedPhotoPath
        }
    }

    private func saveAndContinue() {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !n.isEmpty else {
            errorText = "Please enter your name"
            return
        }
        guard isValidEmail(e) else {
            errorText = "Please enter a valid email"
            hideKeyboard()
            toastMessage = "Please enter a valid email"
            withAnimation { showToast = true }
            return
        }
        errorText = nil

        let finalPath = persistDraftImageIfNeeded()
        store.saveProfile(name: n, email: e, photoPath: finalPath, isRegistered: false)

        // Wait for Mailchimp message toast in onReceive
        hideKeyboard()
    }

    /// Decide if Mailchimp message is "good enough" to advance.
    private func shouldAdvance(after message: String) -> Bool {
        let lower = message.lowercased()
        let okHints = [
            "subscribed",
            "already on the list",
            "already subscribed",
            "subscription confirmed",
            "successfully subscribed",
            "thank you for subscribing",
            "check your email",
            "almost finished"
        ]
        let errorHints = [
            "invalid",
            "failed",
            "couldn’t", "couldn't",
            "try again",
            "too many attempts",
            "network error"
        ]
        if errorHints.contains(where: { lower.contains($0) }) { return false }
        if okHints.contains(where: { lower.contains($0) }) { return true }
        return true
    }
}

// MARK: - Small subviews (kept tiny to help the compiler)

private struct AvatarChooser: View {
    let image: UIImage?
    var body: some View {
        ZStack {
            AvatarCircle(image: image, size: 120)
            Circle()
                .stroke(AppTheme.divider, lineWidth: 1)
                .frame(width: 120, height: 120)
            VStack {
                Spacer()
                Text("Tap to add a photo")
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

// Reuse your avatar circle and image scaler
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

// Self-contained toast for this file
private struct BannerToast: View {
    let message: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
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
        .allowsHitTesting(false)
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
