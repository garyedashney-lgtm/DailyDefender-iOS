import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showShield = false

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var draftPhoto: PhotosPickerItem?
    @State private var draftPhotoData: Data?
    @State private var isLoading = false
    @State private var error: String?

    @State private var showChangePwd = false
    @State private var sendingReset = false
    @State private var resetMessage: String?

    @State private var initialized = false

    private let shieldAsset = "AppShieldSquare"

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {

                    // --- Avatar picker (tap the circle to pick a photo) ---
                    VStack(spacing: 8) {
                        PhotosPicker(selection: $draftPhoto, matching: .images, photoLibrary: .shared()) {
                            ZStack {
                                if let data = draftPhotoData, let img = UIImage(data: data) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 96, height: 96)
                                        .clipShape(Circle())
                                } else if let path = store.profile.photoPath,
                                          let ui = UIImage(contentsOfFile: path) {
                                    Image(uiImage: ui)
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
                            .contentShape(Rectangle()) // ensure the whole circle area is tappable
                        }
                        .disabled(isLoading)

                        Text("Tap the circle to change photo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // --- Name field ---
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(AppTheme.surfaceUI)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.25)))
                        .foregroundStyle(AppTheme.textPrimary)
                        .disabled(isLoading)

                    // --- Read-only email ---
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Account email")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(email.isEmpty ? "—" : email)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                    }

                    // --- Error ---
                    if let e = error, !e.isEmpty {
                        Text(e)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // --- Buttons: Cancel | Save (equal width) ---
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .disabled(isLoading)

                        Button {
                            saveProfile()
                        } label: {
                            if isLoading {
                                HStack { ProgressView().scaleEffect(0.8); Text("Saving…") }
                            } else {
                                Text("Save Changes")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .disabled(isLoading)
                    }
                    .padding(.top, 8)

                    // --- Change Password ---
                    DisclosureGroup(isExpanded: $showChangePwd) {
                        VStack(alignment: .leading, spacing: 10) {
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
                                } else {
                                    Text("Send Password Reset Email")
                                }
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, minHeight: 44)
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

                    Spacer(minLength: 24)
                }
                .padding(16)
            }
        }
        // --- Standardized toolbar ---
        .toolbar {
            // LEFT — Shield (replaces back arrow)
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showShield = true }) {
                    (UIImage(named: shieldAsset) != nil
                     ? Image(shieldAsset).resizable().scaledToFit()
                     : Image("AppShieldSquare").resizable().scaledToFit()
                    )
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.textSecondary.opacity(0.4), lineWidth: 1))
                    .padding(4)
                    .offset(y: -2)
                }
            }

            // CENTER — Title only
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

            // RIGHT — Avatar preview
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

        // --- Shield full-screen ---
        .fullScreenCover(isPresented: $showShield) {
            ShieldPage(
                imageName: (UIImage(named: shieldAsset) != nil ? shieldAsset : "AppShieldSquare")
            )
        }

        // --- Load avatar photo ---
        .task(id: draftPhoto) {
            guard let item = draftPhoto, !isLoading else { return }
            if let data = try? await item.loadTransferable(type: Data.self) {
                draftPhotoData = data
            }
        }
        .onAppear {
            if !initialized {
                name = store.profile.name ?? ""
                email = store.profile.email ?? ""
                initialized = true
            }
        }
    }

    // MARK: - Helpers
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
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(filename)
                try? data.write(to: url)
                finalPhotoPath = url.path
            }

            store.saveProfile(name: n, email: e, photoPath: finalPhotoPath, isRegistered: true)
            await session.runSeedIfNeeded()
            await session.refreshEntitlements()

            isLoading = false
            dismiss()
        }
    }

    private func sendReset() async {
        guard !email.isEmpty else { return }
        sendingReset = true
        resetMessage = nil
        do {
            try await session.sendPasswordReset(to: email)
            resetMessage = "Password reset email sent."
        } catch {
            resetMessage = "Could not send reset email."
        }
        sendingReset = false
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
}
