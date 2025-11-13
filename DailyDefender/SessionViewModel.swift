import Foundation
import FirebaseAuth
import FirebaseFirestore

enum UserTier {
    case free
    case amateur
    case pro
}

@MainActor
final class SessionViewModel: ObservableObject {
    typealias AuthUser = FirebaseAuth.User

    @Published var user: AuthUser?
    @Published var isPro: Bool = false          // legacy flag, derived from `tier`
    @Published var tier: UserTier = .free       // 3-level entitlements
    @Published var errorMessage: String?

    private var userListener: ListenerRegistration?

    // Expose Firestore for read-only use elsewhere (RegistrationView, etc.)
    var db: Firestore { FirebaseService.shared.db }

    init() {
        FirebaseService.shared.configureIfNeeded()
        print("APP BUNDLE:", Bundle.main.bundleIdentifier ?? "nil")

        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }

                // Update current user
                self.user = user

                // Tear down previous listener
                self.userListener?.remove()
                self.userListener = nil

                if let uid = user?.uid {
                    // Live listen to entitlement flips (tier + legacy pro)
                    self.userListener = self.db.collection("users").document(uid)
                        .addSnapshotListener { [weak self] snap, _ in
                            guard let self else { return }
                            guard let data = snap?.data() else {
                                self.applyEntitlementsFromData(nil)
                                return
                            }
                            self.applyEntitlementsFromData(data)
                        }

                    // Seed then refresh entitlements
                    await self.runSeedIfNeeded()
                    await self.refreshEntitlements()
                } else {
                    // Signed out → reset entitlements
                    self.applyEntitlementsFromData(nil)
                }
            }
        }
    }

    deinit {
        userListener?.remove()
    }

    // MARK: - Entitlement resolution

    /// Central place to map Firestore fields -> UserTier + isPro
    private func applyEntitlementsFromData(_ data: [String: Any]?) {
        let anyTier  = data?["tier"]
        let rawTier  = anyTier as? String
        let tierText = rawTier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let legacyPro = (data?["pro"] as? Bool) == true

        #if DEBUG
        print("Entitlements: raw tier=\(rawTier ?? "nil"), normalized=\(tierText ?? "nil"), hasTier=\(anyTier != nil), legacyPro=\(legacyPro)")
        #endif

        let resolvedTier: UserTier

        if anyTier != nil {
            // 🔴 IMPORTANT:
            // If *any* tier is present:
            // - "pro"  -> Pro
            // - anything else (including "amateur", typos, or weird strings) -> Amateur
            switch tierText {
            case "pro":
                resolvedTier = .pro
            default:
                resolvedTier = .amateur
            }
        } else {
            // No tier field at all:
            // - If legacy pro is true -> Pro
            // - Otherwise -> Free
            if legacyPro {
                resolvedTier = .pro
            } else {
                resolvedTier = .free
            }
        }

        self.tier = resolvedTier
        self.isPro = (resolvedTier == .pro)
    }

    // MARK: - Auth

    /// Android-style: try sign-in first, then register if needed
    func signInOrRegister(email: String, password: String) async -> Bool {
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
            return true
        } catch {
            do {
                _ = try await Auth.auth().createUser(withEmail: email, password: password)
                return true
            } catch {
                self.errorMessage = friendly(error)
                return false
            }
        }
    }

    func sendPasswordReset(to email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        guard let uid = user?.uid else {
            applyEntitlementsFromData(nil)
            return
        }
        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            if let data = snap.data() {
                applyEntitlementsFromData(data)
            } else {
                applyEntitlementsFromData(nil)
            }
        } catch {
            applyEntitlementsFromData(nil)
        }
    }

    /// Robust seeding that doesn't rely on /seeds read permission.
    /// - Ensures users/{uid} exists/has baseline fields, then best-effort marks /seeds/{uid}.
    func runSeedIfNeeded() async {
        guard let user = self.user else { return }
        let uid   = user.uid
        let email = user.email ?? ""
        let name  = user.displayName
        let photo = user.photoURL?.absoluteString

        let userDoc = db.collection("users").document(uid)
        let seedDoc = db.collection("seeds").document(uid)

        do {
            let userSnap = try await userDoc.getDocument()
            #if DEBUG
            print("runSeedIfNeeded: user doc exists? \(userSnap.exists ? "yes" : "no")")
            #endif

            await FirestoreSeeder.seedOrMergeUser(
                db: db,
                uid: uid,
                email: email,
                displayName: name,
                photoURL: photo
            )

            // Best-effort seed marker
            do {
                try await seedDoc.setData([
                    "seededAt": Timestamp(date: Date()),
                    "version": 1
                ], merge: true)
            } catch {
                #if DEBUG
                print("runSeedIfNeeded: could not write seeds doc (ok): \(error.localizedDescription)")
                #endif
            }
        } catch {
            #if DEBUG
            print("runSeedIfNeeded: read users/{uid} failed; attempting seed anyway: \(error.localizedDescription)")
            #endif

            await FirestoreSeeder.seedOrMergeUser(
                db: db,
                uid: uid,
                email: email,
                displayName: name,
                photoURL: photo
            )

            do {
                try await seedDoc.setData([
                    "seededAt": Timestamp(date: Date()),
                    "version": 1
                ], merge: true)
            } catch {
                #if DEBUG
                print("runSeedIfNeeded: seeds write failed (ok): \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - Profile helpers (Auth + Firestore)

    /// Update Firebase Auth profile (displayName / photoURL) from strings.
    func updateAuthProfile(displayName: String?, photoURLString: String?) async {
        guard let cu = Auth.auth().currentUser else { return }
        do {
            let change = cu.createProfileChangeRequest()
            if let dn = displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !dn.isEmpty {
                change.displayName = dn
            }
            if let s = photoURLString, let url = URL(string: s) {
                change.photoURL = url
            }
            try await change.commitChanges()
            // Refresh cached user
            self.user = Auth.auth().currentUser
        } catch {
            #if DEBUG
            print("updateAuthProfile error: \(error.localizedDescription)")
            #endif
        }
    }

    /// Upsert users/{uid} with displayName/emailLower/**photoUrl** (canonical), without touching `pro`.
    /// Also deletes legacy `photoURL` if present to avoid duplicates.
    func upsertUserDoc(name: String, email: String, photoURLString: String?) async {
        guard let uid = user?.uid else { return }

        var data: [String: Any] = [
            "displayName": name,
            "email": email,
            "emailLower": email.lowercased(),
            "updatedAt": Timestamp(date: Date())
        ]

        // Canonical key
        if let s = photoURLString, !s.isEmpty {
            data["photoUrl"] = s
        } else {
            // If there's no photo, ensure canonical slot is removed
            data["photoUrl"] = FieldValue.delete()
        }

        do {
            try await db.collection("users").document(uid).setData(data, merge: true)
            // Remove legacy key if it exists
            try? await db.collection("users").document(uid).updateData([
                "photoURL": FieldValue.delete()
            ])
        } catch {
            #if DEBUG
            print("upsertUserDoc failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Generic merge helper (optional use).
    func mergeUserDoc(fields: [String: Any]) async {
        guard let uid = user?.uid else { return }
        do {
            try await db.collection("users").document(uid).setData(fields, merge: true)
        } catch {
            #if DEBUG
            print("mergeUserDoc error: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Error mapping

    private func friendly(_ error: Error) -> String {
        let ns = error as NSError
        if let authErr = AuthErrorCode(_bridgedNSError: ns) {
            switch authErr.code {
            case .wrongPassword, .invalidCredential, .invalidEmail, .userNotFound, .emailAlreadyInUse:
                return "Email or password is incorrect."
            case .weakPassword:
                return "Password is too weak."
            case .networkError:
                return "Network error. Check your connection."
            default: break
            }
        }
        return ns.localizedDescription
    }
}
