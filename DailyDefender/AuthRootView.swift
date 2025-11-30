import SwiftUI
import FirebaseAuth

private enum IosAuthScreen {
    case entry
    case register
    case signIn
}

struct AuthRootView: View {
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var session: SessionViewModel

    let onAuthenticated: () -> Void

    @State private var screen: IosAuthScreen = .entry
    @State private var didForceEntryOnce = false   // 👈 guard to force entry on first appear

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            switch screen {
            case .entry:
                AuthEntryView(
                    onCreateAccount: { screen = .register },
                    onSignIn: { screen = .signIn }
                )

            case .register:
                // Registration flow:
                // - signs in
                // - saves profile locally
                // - updates Firestore + entitlements
                RegistrationView(
                    onRegistered: {
                        Task {
                            // 🔑 Mirror old AuthGateView behavior:
                            // ensure the user doc is seeded + entitlements refreshed
                            await session.runSeedIfNeeded()
                            await session.refreshEntitlements()
                            // Then hand control back to RootView
                            onAuthenticated()
                        }
                    },
                    onBack: {
                        screen = .entry
                    }
                )
                .environmentObject(session)
                .environmentObject(store)

            case .signIn:
                SignInView(
                    onSignedIn: {
                        onAuthenticated()
                    },
                    onBack: {
                        screen = .entry
                    }
                )
                .environmentObject(session)
                .environmentObject(store)
            }
        }
        // 🔧 Any time this AuthRootView is created/shown fresh,
        // force it back to the "entry" state once.
        .onAppear {
            if !didForceEntryOnce {
                screen = .entry
                didForceEntryOnce = true
            }
        }
    }
}

// MARK: - AuthEntry (Welcome) view

struct AuthEntryView: View {
    let onCreateAccount: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navy900.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    // App icon / shield
                    if UIImage(named: "AppShieldSquare") != nil {
                        Image("AppShieldSquare")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(radius: 8)
                    } else {
                        Image(systemName: "shield.lefthalf.filled")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .foregroundStyle(.white)
                            .shadow(radius: 8)
                    }

                    VStack(spacing: 6) {
                        Text("Welcome to 10MM")
                            .font(.title.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Sign in or create your account to continue.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        Button(action: onCreateAccount) {
                            Text("Create account")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.appGreen)

                        Button(action: onSignIn) {
                            Text("Sign in")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.bordered)

                        // 🔒 App Privacy Manifesto link (shown to everyone on first screen)
                        NavigationLink {
                            PrivacyManifestoView()
                        } label: {
                            HStack(spacing: 6) {
                                Text("🔒 App Privacy Manifesto")
                                    .font(.footnote.weight(.semibold))

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                                    .baselineOffset(1)
                            }
                            .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - SignInView (existing user sign-in)

struct SignInView: View {
    @EnvironmentObject var session: SessionViewModel
    @EnvironmentObject var store: HabitStore

    let onSignedIn: () -> Void
    let onBack: () -> Void

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword = false
    @State private var errorText: String?
    @State private var isLoading = false
    @State private var showReset = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navy900.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        // Title
                        VStack(spacing: 6) {
                            Text("Sign in")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Use your 10MM email and password.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.top, 20)

                        // Email
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .padding(12)
                            .background(AppTheme.surfaceUI)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.25))
                            )
                            .foregroundStyle(AppTheme.textPrimary)
                            .disabled(isLoading)

                        // Password + eye
                        ZStack(alignment: .trailing) {
                            Group {
                                if showPassword {
                                    TextField("Password", text: $password)
                                } else {
                                    SecureField("Password", text: $password)
                                }
                            }
                            .textContentType(.password)
                            .padding(12)
                            .background(AppTheme.surfaceUI)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.25))
                            )
                            .foregroundStyle(AppTheme.textPrimary)

                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .padding(.trailing, 12)
                            }
                        }
                        .disabled(isLoading)

                        // Error + reset
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

                        // Sign in button — same size as welcome buttons
                        Button(action: signInTapped) {
                            if isLoading {
                                HStack {
                                    ProgressView().scaleEffect(0.8)
                                    Text("Signing in…")
                                }
                                .frame(maxWidth: .infinity, minHeight: 48)
                            } else {
                                Text("Sign in")
                                    .frame(maxWidth: .infinity, minHeight: 48)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.appGreen)
                        .disabled(isLoading)
                        .padding(.top, 10)

                        // 🔒 App Privacy Manifesto link (for returning users too)
                        NavigationLink {
                            PrivacyManifestoView()
                        } label: {
                            HStack(spacing: 6) {
                                Text("🔒 App Privacy Manifesto")
                                    .font(.footnote.weight(.semibold))

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                                    .baselineOffset(1)
                            }
                            .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
                .scrollContentBackground(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { if !isLoading { onBack() } }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Sign in")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.navy900, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Logic

    private func signInTapped() {
        guard !isLoading else { return }

        let e = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let p = password

        guard !e.isEmpty, !p.isEmpty else {
            errorText = "Please enter your email and password."
            return
        }

        // 🔐 Local one-account-per-device guard (email-based)
        let localEmail = store.profile.email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if !localEmail.isEmpty, e != localEmail {
            // This device already has a bound account; don't even hit Firebase
            errorText = "This device is already registered to another account."
            showReset = false
            return
        }

        // No more pure local-email gate – but we still have UID binding below
        errorText = nil
        showReset = false
        isLoading = true

        Task {
            do {
                // 1) Sign in with Firebase
                try await Auth.auth().signIn(withEmail: e, password: p)

                guard let user = Auth.auth().currentUser else {
                    throw NSError(
                        domain: "Auth",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No user after sign-in"]
                    )
                }

                let uid = user.uid

                // 2) Enforce one-account-per-device by UID (backup guard)
                let binding = DeviceBindingManagerIOS()
                if let deviceOwner = binding.getDeviceOwnerUid() {
                    if deviceOwner != uid {
                        // Different user trying to claim this device → block
                        try? Auth.auth().signOut()
                        errorText = "This device is already registered to another account."
                        showReset = false
                        isLoading = false
                        return
                    }
                } else {
                    // First account on this device → claim it
                    binding.setDeviceOwnerUid(uid)
                }

                // 3) Hydrate local profile
                let displayName = user.displayName ?? ""
                let emailLower = (user.email ?? e)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()

                store.saveProfile(
                    name: displayName.isEmpty ? store.profile.name ?? "" : displayName,
                    email: emailLower,
                    photoPath: store.profile.photoPath,
                    isRegistered: true
                )

                // 4) Entitlements + device registration (server-side binding)
                await session.runSeedIfNeeded()
                await session.refreshEntitlements()
                await session.registerCurrentDevice()

                isLoading = false
                onSignedIn()
            } catch {
                let nsError = error as NSError
                print("🔥 signIn error:", nsError.localizedDescription, "rawCode=\(nsError.code)")

                errorText = "Email or password is incorrect."
                showReset = true
                isLoading = false
            }
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
                errorText = "If \(e) is registered, we’ve emailed instructions to reset your password."
                // you can optionally keep showReset = true so they can tap again
            } catch {
                let nsError = error as NSError
                print("🔥 sendPasswordReset error:", nsError.localizedDescription, "rawCode=\(nsError.code)")
                errorText = "We couldn't send a reset email. Please double-check the address."
            }
        }
    }

    private func isValidEmail(_ s: String) -> Bool {
        s.contains("@") && s.contains(".") && !s.hasPrefix("@") && !s.hasSuffix("@")
    }
}

// MARK: - Device Binding Helper (iOS)

final class DeviceBindingManagerIOS {
    private let key = "deviceOwnerUid_ios"

    func getDeviceOwnerUid() -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    func setDeviceOwnerUid(_ uid: String) {
        UserDefaults.standard.set(uid, forKey: key)
    }
}
