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
                RegistrationView {
                    Task {
                        // 🔑 Mirror old AuthGateView behavior:
                        // ensure the user doc is seeded + entitlements refreshed
                        await session.runSeedIfNeeded()
                        await session.refreshEntitlements()
                        // Then hand control back to RootView
                        onAuthenticated()
                    }
                }
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
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.25)))
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
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.25)))
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

                        // Sign in button
                        Button(action: signInTapped) {
                            if isLoading {
                                HStack { ProgressView().scaleEffect(0.8); Text("Signing in…") }
                            } else {
                                Text("Sign in")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .disabled(isLoading)
                        .padding(.top, 6)

                        // Back
                        Button(action: { if !isLoading { onBack() } }) {
                            Text("Back")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
                .scrollContentBackground(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { if !isLoading { onBack() } }) {
                        Image(systemName: "chevron.left")
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

    private func signInTapped() {
        guard !isLoading else { return }

        let e = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let p = password

        guard !e.isEmpty, !p.isEmpty else {
            errorText = "Please enter your email and password."
            return
        }

        errorText = nil
        showReset = false
        isLoading = true

        Task {
            do {
                // Pure sign-in using FirebaseAuth
                try await Auth.auth().signIn(withEmail: e, password: p)

                // Hydrate local profile from FirebaseAuth user
                if let user = Auth.auth().currentUser {
                    let displayName = user.displayName ?? ""
                    let emailLower = user.email ?? e

                    // Journals remain local, but we mark this profile as registered
                    store.saveProfile(
                        name: displayName,
                        email: emailLower,
                        photoPath: store.profile.photoPath, // keep any existing local photo if present
                        isRegistered: true
                    )
                }

                // Refresh entitlements / seed user doc if needed
                await session.runSeedIfNeeded()
                await session.refreshEntitlements()

                isLoading = false
                onSignedIn()
            } catch {
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
                errorText = nil
            } catch {
                errorText = "Email or password is incorrect."
            }
        }
    }

    private func isValidEmail(_ s: String) -> Bool {
        s.contains("@") && s.contains(".") && !s.hasPrefix("@") && !s.hasSuffix("@")
    }
}
