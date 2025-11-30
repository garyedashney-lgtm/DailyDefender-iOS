import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileEditView: View {
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Profile State
    @State private var name: String = ""
    @State private var email: String = ""              // live email from Firebase
    @State private var appLevelLabel: String = "Free"  // live app level from Firestore

    @State private var draftPhoto: PhotosPickerItem?
    @State private var draftPhotoData: Data?
    @State private var isLoading = false
    @State private var error: String?

    // MARK: - Change Password Section
    @State private var showChangePwd = false
    @State private var sendingReset = false
    @State private var resetMessage: String?

    // MARK: - Change Login Email Section
    @State private var showChangeEmail = false
    @State private var currentPasswordForEmail = ""
    @State private var newLoginEmail = ""
    @State private var confirmLoginEmail = ""
    @State private var sendingEmailChange = false
    @State private var changeEmailError: String?
    @State private var showEmailChangePassword = false   // eye toggle

    // MARK: - Misc
    @State private var showSignOutConfirm = false
    @State private var showShield = false
    @State private var toastMessage: String?
    @State private var initialized = false

    private let shieldAsset = "AppShieldSquare"

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    avatarSection
                    nameField
                    accountInfoSection

                    if let e = error, !e.isEmpty {
                        errorText(e)
                    }

                    saveCancelButtons
                    changeLoginEmailSection
                    changePasswordSection
                    signOutSection

                    Spacer(minLength: 24)
                }
                .padding(16)
            }

            toastBanner
        }
        // MARK: - Toolbar
        .toolbar {
            // LEFT: Shield
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showShield = true } label: {
                    (UIImage(named: shieldAsset) != nil
                     ? Image(shieldAsset).resizable().scaledToFit()
                     : Image("AppShieldSquare").resizable().scaledToFit()
                    )
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppTheme.textSecondary.opacity(0.4), lineWidth: 1)
                    )
                    .padding(4)
                    .offset(y: -2)
                }
            }

            // CENTER: Title
            ToolbarItem(placement: .principal) {
                VStack(spacing: 6) {
                    Text("Edit Profile")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Account & photo")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.bottom, 10)
            }

            // RIGHT: Avatar chip
            ToolbarItem(placement: .navigationBarTrailing) {
                Group {
                    if let path = store.profile.photoPath,
                       let ui = UIImage(contentsOfFile: path) {
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
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.navy900, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 48) }

        // Shield page
        .fullScreenCover(isPresented: $showShield) {
            ShieldPage(
                imageName: (UIImage(named: shieldAsset) != nil ? shieldAsset : "AppShieldSquare")
            )
        }

        // Avatar load
        .task(id: draftPhoto) {
            await loadPickedAvatar()
        }

        .onAppear {
            if !initialized {
                initialized = true
                name = store.profile.name ?? ""
                email = store.profile.email ?? ""

                Task { await refreshAccountFromFirebase() }
            }
        }

        .alert("Sign out?", isPresented: $showSignOutConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Sign out", role: .destructive) { performSignOut() }
        } message: {
            Text("You’ll need to sign in again to access your Journals and Pro features.")
        }
    }
}

// MARK: - UI Sections

extension ProfileEditView {

    // MARK: Avatar
    private var avatarSection: some View {
        VStack(spacing: 8) {
            PhotosPicker(selection: $draftPhoto, matching: .images, photoLibrary: .shared()) {
                ZStack {
                    if let data = draftPhotoData, let img = UIImage(data: data) {
                        avatarImage(img)
                    } else if let path = store.profile.photoPath,
                              let ui = UIImage(contentsOfFile: path) {
                        avatarImage(ui)
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 112, height: 112)
                            .overlay(
                                Text(initials(from: name))
                                    .font(.title.bold())
                                    .foregroundStyle(.white)
                            )
                    }
                }
                .contentShape(Rectangle())   // makes whole 120x120 hitbox tappable
            }
            .frame(width: 120, height: 120) // 🔥 bigger tap target + visual size
            .padding(.vertical, 4)
            .disabled(isLoading)

            Text("Tap the circle to change photo")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func avatarImage(_ ui: UIImage) -> some View {
        Image(uiImage: ui)
            .resizable()
            .scaledToFill()
            .frame(width: 112, height: 112)  // match placeholder size
            .clipShape(Circle())
    }

    // MARK: Name Field
    private var nameField: some View {
        TextField("Name", text: $name)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .padding(12)
            .background(AppTheme.surfaceUI)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.25))
            )
            .foregroundStyle(AppTheme.textPrimary)
            .disabled(isLoading)
    }

    // MARK: Account Email + App Level
    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Account email:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(email.isEmpty ? "—" : email)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack(spacing: 8) {
                Text("App level:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(appLevelLabel)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Error
    private func errorText(_ msg: String) -> some View {
        Text(msg)
            .foregroundStyle(.red)
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Save / Cancel Row
    private var saveCancelButtons: some View {
        HStack(spacing: 12) {
            Button(action: { if !isLoading { dismiss() } }) {
                Text("Cancel")
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.bordered)

            Button(action: { if !isLoading { saveProfile() } }) {
                if isLoading {
                    HStack {
                        ProgressView().scaleEffect(0.8)
                        Text("Saving…")
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                } else {
                    Text("Save Changes")
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 8)
    }

    // MARK: Change Login Email
    private var changeLoginEmailSection: some View {
        DisclosureGroup(isExpanded: $showChangeEmail) {
            VStack(alignment: .leading, spacing: 12) {
                Text("You’ll need your current password.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                // Password + eye
                HStack {
                    if showEmailChangePassword {
                        TextField("Current password", text: $currentPasswordForEmail)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("Current password", text: $currentPasswordForEmail)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    Button { showEmailChangePassword.toggle() } label: {
                        Image(systemName: showEmailChangePassword ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .disabled(sendingEmailChange)
                }
                .padding(10)
                .background(AppTheme.surfaceUI)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.25))
                )

                TextField("New email", text: $newLoginEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(AppTheme.surfaceUI)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.25))
                    )

                TextField("Confirm new email", text: $confirmLoginEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(AppTheme.surfaceUI)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.25))
                    )

                if let msg = changeEmailError, !msg.isEmpty {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                HStack {
                    Spacer()
                    Button {
                        Task { await changeLoginEmail() }
                    } label: {
                        if sendingEmailChange {
                            HStack {
                                ProgressView().scaleEffect(0.8)
                                Text("Updating…")
                            }
                            .frame(minHeight: 44)
                        } else {
                            Text("Update email")
                                .frame(minHeight: 44)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(sendingEmailChange)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text("Change Login Email")
                    .font(.body.weight(.semibold))
                Spacer()
                Image(systemName: showChangeEmail ? "chevron.down" : "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
        .padding(.top, 8)
    }

    // MARK: Change Password
    private var changePasswordSection: some View {
        DisclosureGroup(isExpanded: $showChangePwd) {
            VStack(alignment: .leading, spacing: 12) {

                Text("We’ll email a secure password reset link to:")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(email.isEmpty ? "—" : email)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                if let msg = resetMessage, !msg.isEmpty {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await sendReset() }
                } label: {
                    if sendingReset {
                        HStack { ProgressView().scaleEffect(0.8); Text("Sending…") }
                            .frame(maxWidth: .infinity, minHeight: 44)
                    } else {
                        Text("Send Password Reset Email")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(sendingReset || email.isEmpty)
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text("Change Password")
                    .font(.body.weight(.semibold))
                Spacer()
                Image(systemName: showChangePwd ? "chevron.down" : "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
        .padding(.top, 8)
    }

    // MARK: Sign Out + Manifesto Note
    private var signOutSection: some View {
        Group {
            if Auth.auth().currentUser != nil {
                Divider()
                    .padding(.top, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Account")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        if !isLoading {
                            showSignOutConfirm = true
                        }
                    } label: {
                        Text("Sign out")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red.opacity(0.8))

                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "iphone")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.top, 2)

                        Text("Your journal entries, goals, and notes remain on this device after you sign out.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: Toast
    private var toastBanner: some View {
        Group {
            if let toast = toastMessage {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.85))
                        .foregroundStyle(.white)
                        .cornerRadius(20)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.easeInOut(duration: 0.25), value: toast)
            }
        }
    }
}

// MARK: - Logic

extension ProfileEditView {

    // Avatar load
    private func loadPickedAvatar() async {
        guard let item = draftPhoto, !isLoading else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            await MainActor.run {
                draftPhotoData = data
            }
        }
    }

    // Save profile
    private func saveProfile() {
        guard !isLoading else { return }

        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if n.isEmpty { error = "Please enter your name"; return }
        if !isValidEmail(e) { error = "Please enter a valid email"; return }

        error = nil
        isLoading = true

        Task {
            var finalPhotoPath: String? = store.profile.photoPath

            if let data = draftPhotoData {
                let filename = "profile_\(UUID().uuidString).jpg"
                let url = FileManager.default
                    .urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(filename)
                try? data.write(to: url)
                finalPhotoPath = url.path
            }

            store.saveProfile(
                name: n,
                email: e,
                photoPath: finalPhotoPath,
                isRegistered: true
            )

            await session.updateAuthProfile(
                displayName: n,
                photoURLString: finalPhotoPath
            )
            await session.upsertUserDoc(
                name: n,
                email: e,
                photoURLString: finalPhotoPath
            )

            await session.runSeedIfNeeded()
            await session.refreshEntitlements()

            await MainActor.run {
                isLoading = false
                toastMessage = "Profile saved."
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { toastMessage = nil }
                dismiss()
            }
        }
    }

    // Send password reset (Change Password section)
    private func sendReset() async {
        guard !email.isEmpty else { return }
        await MainActor.run {
            sendingReset = true
            resetMessage = nil
        }
        do {
            try await session.sendPasswordReset(to: email)
            await MainActor.run {
                resetMessage = "Password reset email sent."
            }
        } catch {
            await MainActor.run {
                resetMessage = "Could not send reset email."
            }
        }
        await MainActor.run {
            sendingReset = false
        }
    }

    // MARK: Change login email — verify-before-update (Android-style)
    private func changeLoginEmail() async {
        let pwd = currentPasswordForEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let newE = newLoginEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let conf = confirmLoginEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let oldE = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if pwd.isEmpty {
            changeEmailError = "Enter your current password."
            return
        }
        if !isValidEmail(newE) {
            changeEmailError = "Enter a valid email."
            return
        }
        if newE == oldE {
            changeEmailError = "New email must be different from current email."
            return
        }
        if newE != conf {
            changeEmailError = "New email and confirmation do not match."
            return
        }

        await MainActor.run {
            sendingEmailChange = true
            changeEmailError = nil
        }

        do {
            guard let user = Auth.auth().currentUser else {
                throw NSError(
                    domain: "ProfileEditView",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "You must be signed in to change your email."]
                )
            }

            // 1) Re-authenticate with current email + password
            let credential = EmailAuthProvider.credential(withEmail: oldE, password: pwd)
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                user.reauthenticate(with: credential) { _, error in
                    if let error = error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume(returning: ())
                    }
                }
            }

            // 2) Start Firebase's verify-before-update flow
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                user.sendEmailVerification(beforeUpdatingEmail: newE) { error in
                    if let error = error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume(returning: ())
                    }
                }
            }

            // 3) Record pendingEmail in Firestore (so we can promote it later)
            let db = Firestore.firestore()
            try await db.collection("users")
                .document(user.uid)
                .setData(
                    [
                        "pendingEmail": newE,
                        "emailChangeRequestedAt": FieldValue.serverTimestamp()
                    ],
                    merge: true
                )

            await MainActor.run {
                toastMessage = "We’ve emailed \(newE). Tap the link to finish the change.\nUntil then, keep signing in with \(oldE)."

                currentPasswordForEmail = ""
                newLoginEmail = ""
                confirmLoginEmail = ""
                showChangeEmail = false
                changeEmailError = nil
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { toastMessage = nil }
            }

        } catch {
            await MainActor.run {
                let nsError = error as NSError
                print("🔥 changeLoginEmail error:", nsError.localizedDescription, "rawCode=\(nsError.code)")

                if nsError.code == AuthErrorCode.requiresRecentLogin.rawValue {
                    changeEmailError = "For security, please sign in again, then try changing your email."
                } else {
                    changeEmailError = nsError.localizedDescription.isEmpty
                    ? "Could not start email change."
                    : nsError.localizedDescription
                }
            }
        }

        await MainActor.run {
            sendingEmailChange = false
        }
    }

    // Refresh from Firebase
    private func refreshAccountFromFirebase() async {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()

        do {
            // Reload auth user to pull latest email
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                user.reload { error in
                    if let error = error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume(returning: ())
                    }
                }
            }

            let fresh = Auth.auth().currentUser ?? user
            let authEmail = (fresh.email ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let docRef = db.collection("users").document(fresh.uid)
            let snapshot = try await docRef.getDocument()

            var firestoreEmail: String? = nil
            var tierLabel = "Free"

            if let data = snapshot.data() {
                firestoreEmail = (data["email"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if let rawTier = (data["tier"] as? String) ??
                    (data["appLevel"] as? String) ??
                    (data["plan"] as? String) {
                    let normalized = rawTier.uppercased()
                    switch normalized {
                    case "FREE": tierLabel = "Free"
                    case "AMATEUR", "STANDARD": tierLabel = "Standard"
                    case "PRO": tierLabel = "Pro"
                    default: tierLabel = rawTier
                    }
                }
            }

            let finalEmail: String
            if let fire = firestoreEmail, !fire.isEmpty {
                finalEmail = fire
            } else if !authEmail.isEmpty {
                finalEmail = authEmail
            } else {
                finalEmail = email
            }

            await MainActor.run {
                self.email = finalEmail
                self.appLevelLabel = tierLabel

                store.saveProfile(
                    name: store.profile.name ?? self.name,
                    email: finalEmail,
                    photoPath: store.profile.photoPath,
                    isRegistered: store.profile.isRegistered
                )
            }

        } catch {
            print("refreshAccountFromFirebase error: \(error.localizedDescription)")
            let fallback = (Auth.auth().currentUser?.email ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !fallback.isEmpty {
                await MainActor.run {
                    self.email = fallback
                }
            }
        }
    }

    // MARK: Validation helpers
    private func isValidEmail(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        return t.contains("@") && t.contains(".")
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let f = parts.first?.first.map(String.init) ?? "D"
        let s = parts.dropFirst().first?.first.map(String.init) ?? "D"
        return f + s
    }

    private func performSignOut() {
        // Sign out of Firebase
        do {
            try Auth.auth().signOut()
        } catch {
            print("Sign out error:", error.localizedDescription)
        }

        // Keep local data, just mark profile as not registered
        store.saveProfile(
            name: store.profile.name ?? "",
            email: store.profile.email ?? "",
            photoPath: store.profile.photoPath,
            isRegistered: false
        )

        // Pop back to auth flow
        dismiss()
    }
}
