import SwiftUI
import PhotosUI
import FirebaseFirestore

struct RegistrationView: View {
    @EnvironmentObject var session: SessionViewModel
    @EnvironmentObject var store: HabitStore
    let onRegistered: () -> Void

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorText: String?
    @State private var isLoading = false
    @State private var showPassword = false
    @State private var showReset = false

    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoUri: String?

    @State private var initialized = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navy900.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {

                        // Avatar (tap to pick a photo)
                        PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                            ZStack {
                                if let data = photoData, let img = UIImage(data: data) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 96, height: 96)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 96, height: 96)
                                        .overlay(
                                            Text(initials(from: name))
                                                .font(.title.bold())
                                                .foregroundStyle(.white)
                                        )
                                }
                            }
                        }
                        .disabled(isLoading)

                        // Name
                        TextField("Name", text: $name)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(AppTheme.surfaceUI)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.25)))
                            .foregroundStyle(AppTheme.textPrimary)
                            .disabled(isLoading)

                        // Email
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .padding(12)
                            .background(AppTheme.surfaceUI)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.25)))
                            .foregroundStyle(AppTheme.textPrimary)
                            .disabled(isLoading)

                        // Password + eye toggle
                        ZStack(alignment: .trailing) {
                            Group {
                                if showPassword {
                                    TextField("Password (min 6 chars)", text: $password)
                                } else {
                                    SecureField("Password (min 6 chars)", text: $password)
                                }
                            }
                            .textContentType(.password)
                            .padding(12)
                            .background(AppTheme.surfaceUI)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.25)))
                            .foregroundStyle(AppTheme.textPrimary)

                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .padding(.trailing, 12)
                            }
                        }
                        .disabled(isLoading)

                        // Error + reset link
                        VStack(alignment: .leading, spacing: 6) {
                            if let e = errorText {
                                Text(e)
                                    .foregroundStyle(.red)
                                    .font(.footnote)
                            }
                            if showReset {
                                Button {
                                    sendReset()
                                } label: {
                                    Text("Forgot password? Tap here")
                                        .underline()
                                        .font(.body)
                                }
                                .disabled(isLoading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Continue
                        Button(action: continueTapped) {
                            if isLoading {
                                HStack { ProgressView().scaleEffect(0.8); Text("Working…") }
                            } else {
                                Text("Save & Continue")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .disabled(isLoading)
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
                .scrollContentBackground(.hidden) // let navy show through
            }
            .toolbar {
                // LEFT — app shield
                ToolbarItem(placement: .navigationBarLeading) {
                    Group {
                        if UIImage(named: "AppShieldSquare") != nil {
                            Image("AppShieldSquare")
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: "shield.lefthalf.filled")
                                .resizable()
                                .scaledToFit()
                        }
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.textSecondary.opacity(0.4), lineWidth: 1))
                    .padding(4)
                    .offset(y: -2)
                    .accessibilityLabel("App")
                }

                // CENTER — title
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 4) {
                        Text("Create your profile")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Sign in or register to continue")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.bottom, 6)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.navy900, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task(id: photoItem) {
            guard let item = photoItem, !isLoading else { return }
            if let data = try? await item.loadTransferable(type: Data.self) {
                photoData = data
                if let ui = UIImage(data: data) {
                    photoUri = savePhotoToDocuments(ui)
                }
            }
        }
        .onAppear {
            if !initialized {
                initialized = true
            }
        }
    }

    private func continueTapped() {
        guard !isLoading else { return }
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if n.isEmpty { errorText = "Please enter your name"; return }
        if !isValidEmail(e) { errorText = "Please enter a valid email"; return }
        if password.count < 6 { errorText = "Password must be at least 6 characters"; return }

        errorText = nil
        showReset = false
        isLoading = true

        Task {
            let signedIn = await session.signInOrRegister(email: e, password: password)
            if !signedIn {
                showReset = true
                isLoading = false
                return
            }

            // Persist local profile & mark registered
            let finalPhoto = photoUri
            store.saveProfile(name: n, email: e, photoPath: finalPhoto, isRegistered: true)

            // Push name/photo to Auth + Firestore (your helpers)
            await session.updateAuthProfile(displayName: n, photoURLString: finalPhoto)
            await session.upsertUserDoc(name: n, email: e, photoURLString: finalPhoto)

            // 🔧 Normalize Firestore field names: prefer "photoUrl", remove legacy "photoURL"
            if let uid = session.user?.uid {
                let db = session.db
                var merge: [String: Any] = ["updatedAt": FieldValue.serverTimestamp()]
                if let finalPhoto {
                    merge["photoUrl"] = finalPhoto   // ✅ canonical
                } else {
                    merge["photoUrl"] = FieldValue.delete()
                }
                try? await db.collection("users").document(uid).setData(merge, merge: true)
                try? await db.collection("users").document(uid).updateData([
                    "photoURL": FieldValue.delete()  // 🧹 remove legacy key if present
                ])
            }

            // Seed/entitlements
            await session.runSeedIfNeeded()
            await session.refreshEntitlements()

            isLoading = false
            onRegistered()
        }
    }

    private func sendReset() {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidEmail(e) else {
            errorText = "Enter a valid email first to reset your password."
            return
        }
        Task {
            do {
                try await session.sendPasswordReset(to: e)
                errorText = nil
            } catch {
                errorText = "Email or password is incorrect."
            }
        }
    }

    private func isValidEmail(_ s: String) -> Bool {
        s.contains("@") && s.contains(".") && !s.hasPrefix("@") && !s.hasSuffix("@")
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? "D"
        let second = parts.dropFirst().first?.first.map(String.init) ?? "D"
        return first + second
    }

    private func savePhotoToDocuments(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        let filename = UUID().uuidString + ".jpg"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            return nil
        }
    }
}
