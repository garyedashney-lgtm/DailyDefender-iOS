import SwiftUI
import PhotosUI

struct RegistrationView: View {
    @EnvironmentObject var session: SessionViewModel
    @EnvironmentObject var store: HabitStore
    let onRegistered: () -> Void
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var error: String?
    @State private var isLoading = false
    @State private var showPassword = false
    @State private var showReset = false
    
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoUri: String? // path or base64/url string if you persist locally
    
    // Prefill (rough equivalent to Android's profileFlow prefill)
    @State private var initialized = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Avatar (tap the circle to pick a photo)
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
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.secondary))
                        .disabled(isLoading)
                    
                    // Email (read-only if returning signed-out; for simplicity always editable here)
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .padding(12)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.secondary))
                        .disabled(isLoading)
                    
                    // Password with eye toggle
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
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.secondary))
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .padding(.trailing, 10)
                        }
                    }
                    .disabled(isLoading)
                    
                    // Error + Forgot password
                    VStack(alignment: .leading, spacing: 6) {
                        if let e = error {
                            Text(e).foregroundStyle(.red).font(.footnote)
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
                    
                    // Continue button (Android behavior: try sign-in, else register)
                    Button(action: continueTapped) {
                        if isLoading {
                            HStack {
                                ProgressView().scaleEffect(0.8)
                                Text("Working…")
                            }
                        } else {
                            Text("Save & Continue")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .disabled(isLoading)
                    .padding(.top, 8)
                }
                .padding(16)
            }
            .navigationTitle("Create your profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: photoItem) {
            guard let item = photoItem, !isLoading else { return }
            if let data = try? await item.loadTransferable(type: Data.self) {
                photoData = data
                if let ui = UIImage(data: data) {
                    // persist to disk so Profile has a stable path
                    photoUri = savePhotoToDocuments(ui)
                }
            }
        }
        .onAppear {
            // Optionally prefill from a local profile store if you have one (hook up here)
            if !initialized {
                // If your HabitStore exposes a current profile, fill name/email/photoUri here
                // name = store.profile.name ?? ""
                // email = store.profile.email ?? ""
                initialized = true
            }
        }
    }
    
    private func continueTapped() {
        guard !isLoading else { return }
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if n.isEmpty { error = "Please enter your name"; return }
        if !isValidEmail(e) { error = "Please enter a valid email"; return }
        if password.count < 6 { error = "Password must be at least 6 characters"; return }
        
        error = nil
        showReset = false
        isLoading = true
        
        Task {
            // Android-style: try sign-in, else register
            let signedIn = await session.signInOrRegister(email: e, password: password)
            if !signedIn {
                // Sign-in AND register failed — show friendly error and reset link
                showReset = true
                isLoading = false
                return
            }
            
            // 2) Save local profile and mark registered (mirror Android)
            let finalPhoto = photoUri /* or a saved path from PhotosPicker if you implement */
            // Adjust signature if your HabitStore differs:
            store.saveProfile(name: n, email: e, photoPath: finalPhoto, isRegistered: true)
            
            // 2.5) Seed Firestore and try pro=true (rules-gated)
            await session.runSeedIfNeeded()
            await session.refreshEntitlements()
            
            isLoading = false
            onRegistered() // session.user != nil will push to RootView via AuthGateView
        }
    }
    
    private func sendReset() {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidEmail(e) else {
            error = "Enter a valid email first to reset your password."
            return
        }
        Task {
            do {
                try await session.sendPasswordReset(to: e)
                error = nil
            } catch {
                // Keep it generic to avoid account enumeration
                self.error = "Email or password is incorrect."
            }
        }
    }
    
    private func isValidEmail(_ s: String) -> Bool {
        // Simple but effective; replace with stricter regex if you prefer
        return s.contains("@") && s.contains(".") && !s.hasPrefix("@") && !s.hasSuffix("@")
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
