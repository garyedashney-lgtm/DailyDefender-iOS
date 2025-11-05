import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class SessionViewModel: ObservableObject {
    typealias AuthUser = FirebaseAuth.User

    @Published var user: AuthUser?
    @Published var isPro: Bool = false
    @Published var errorMessage: String?

    private var userListener: ListenerRegistration?    // live pro listener
    private var db: Firestore { FirebaseService.shared.db }

    init() {
        FirebaseService.shared.configureIfNeeded()

        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }

                // Update current user
                self.user = user

                // Tear down any previous listener
                self.userListener?.remove()
                self.userListener = nil

                if let uid = user?.uid {
                    // Live-listen to pro flag so tabs unlock immediately when flipped in Firestore
                    self.userListener = self.db.collection("users").document(uid)
                        .addSnapshotListener { [weak self] snap, _ in
                            guard let self else { return }
                            if let data = snap?.data() {
                                self.isPro = (data["pro"] as? Bool) == true
                            }
                        }

                    // Ensure user doc exists before checking entitlements
                    await self.runSeedIfNeeded()
                    await self.refreshEntitlements()
                } else {
                    self.isPro = false
                }
            }
        }
    }

    deinit {
        userListener?.remove()
    }

    // Android-style: try sign-in first, then register if needed
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

    func refreshEntitlements() async {
        guard let uid = user?.uid else { isPro = false; return }
        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            isPro = (snap.data()?["pro"] as? Bool) == true
        } catch {
            isPro = false
        }
    }

    /// Robust seeding that doesn't rely on /seeds read permission.
    /// - Checks users/{uid}; if missing, writes it. Then best-effort marks /seeds/{uid}.
    func runSeedIfNeeded() async {
        guard let user = self.user else { return }
        let uid = user.uid
        let email = user.email ?? ""
        let name = user.displayName
        let photo = user.photoURL?.absoluteString

        let userDoc = db.collection("users").document(uid)
        let seedDoc = db.collection("seeds").document(uid)

        do {
            // Prefer checking the actual users doc
            let userSnap = try await userDoc.getDocument()
            #if DEBUG
            print("runSeedIfNeeded: user doc exists? \(userSnap.exists ? "yes" : "no")")
            #endif

            // Always run an idempotent merge to ensure emailLower/updatedAt/counters are present
            await FirestoreSeeder.seedOrMergeUser(
                db: db,
                uid: uid,
                email: email,
                displayName: name,
                photoURL: photo
            )

            // Best-effort: mark seeded; ignore if rules forbid
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
            // If reading users/{uid} fails, still attempt to seed
            #if DEBUG
            print("runSeedIfNeeded: user doc read failed; attempting seed anyway: \(error.localizedDescription)")
            #endif
            await FirestoreSeeder.seedOrMergeUser(
                db: db,
                uid: uid,
                email: email,
                displayName: name,
                photoURL: photo
            )
            // Try marking seeds, but don't require permissions
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
