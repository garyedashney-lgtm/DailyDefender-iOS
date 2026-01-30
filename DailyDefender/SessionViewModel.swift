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
    @Published var isPro: Bool = false          // derived from `tier` OR active trial
    @Published var tier: UserTier = .free       // 3-level entitlements
    @Published var errorMessage: String?

    // Trial UI/state
    @Published var trialStatus: String? = nil
    @Published var trialEndsAt: Timestamp? = nil
    @Published var trialDaysRemaining: Int? = nil

    // UI triggers (views will listen to these later)
    @Published var shouldShowTrialStartModal: Bool = false
    @Published var shouldShowTrialWarning: Bool = false
    @Published var trialWarningDaysRemaining: Int? = nil

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

                    // 🧷 One-account-per-device: if this device has never been bound,
                    // bind it now to the first uid we see.
                    if DeviceBindingManager.shared.boundUid == nil {
                        DeviceBindingManager.shared.boundUid = uid
                       
                    }

                    // Live listen to entitlement flips (tier + trial + overrides)
                    self.userListener = self.db.collection("users").document(uid)
                        .addSnapshotListener { [weak self] snap, _ in
                            guard let self else { return }
                            let data = snap?.data()
                            self.applyEntitlementsFromData(data, uid: uid)
                        }

                    // Seed then enforce trial then refresh entitlements
                    await self.runSeedIfNeeded()
                    await self.refreshEntitlements()   // refreshEntitlements already enforces trial
                } else {
                    // Signed out → reset entitlements
                    self.applyEntitlementsFromData(nil, uid: nil)
                }
            }
        }
    }

    deinit {
        userListener?.remove()
    }

    // MARK: - Hydrate today's checkmarks from Firestore (cloud → phone)

    /// Pulls users/{uid}/daily/{yyyyMMdd} and applies it to local store + UserDefaults.
    /// Call this when DailyView appears (especially after reinstall/sign-in).
    func hydrateTodayDailyToLocal(store: HabitStore) async {
        guard let uid = user?.uid else { return }

        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.dateFormat = "yyyyMMdd"
        let todayKey = df.string(from: Date())

        let docRef = db
            .collection("users")
            .document(uid)
            .collection("daily")
            .document(todayKey)

        do {
            let snap = try await docRef.getDocument()
            let data = snap.data()
            let completed = (data?["completed"] as? [String]) ?? []

            // 1) Apply to in-memory store
            store.completed = Set(completed)

            // 2) Snapshot to UserDefaults so rolling windows / totals stay consistent
            UserDefaults.standard.set(completed, forKey: "daily_completed_\(todayKey)")

           
        } catch {
          
        }
    }

    // MARK: - Entitlement resolution

    /// Central place to map Firestore fields -> UserTier + isPro + trial UI fields
    private func applyEntitlementsFromData(_ data: [String: Any]?, uid: String?) {
        // ---------------------------
        // Trial read (needed for UI + trial entitlement)
        // ---------------------------
        let trialStatusNorm = (data?["trialStatus"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let trialEndsAt = data?["trialEndsAt"] as? Timestamp
        let now = Date()

        let isTrialActive: Bool = {
            guard trialStatusNorm == "active",
                  let end = trialEndsAt?.dateValue()
            else { return false }
            return now < end
        }()

        // Publish trial UI fields
        self.trialStatus = trialStatusNorm
        self.trialEndsAt = trialEndsAt

        if isTrialActive, let end = trialEndsAt?.dateValue() {
            let days = Calendar.current.dateComponents([.day], from: now, to: end).day
            self.trialDaysRemaining = days.map { max(0, $0) }
        } else {
            self.trialDaysRemaining = nil
        }

        // ---------------------------
        // Tier resolution
        // ---------------------------
        let anyTier  = data?["tier"]
        let rawTier  = anyTier as? String
        let tierText = rawTier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let legacyPro = (data?["pro"] as? Bool) == true

        // Manual override can force access (we’ll enforce later; here is just resolution)
        let overrideText = (data?["tierOverride"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let resolvedTier: UserTier

        if let overrideText, !overrideText.isEmpty {
            // override: "pro" | "amateur"
            if overrideText == "pro" {
                resolvedTier = .pro
            } else if overrideText == "amateur" {
                resolvedTier = .amateur
            } else {
                // unknown override -> fall back safely
                resolvedTier = isTrialActive ? .pro : .free
            }
        } else if isTrialActive {
            // ✅ ACTIVE TRIAL = PRO ENTITLEMENT
            resolvedTier = .pro
        } else if let tierText {
            switch tierText {
            case "pro":     resolvedTier = .pro
            case "amateur": resolvedTier = .amateur
            case "free":    resolvedTier = .free
            default:        resolvedTier = .free
            }
        } else {
            resolvedTier = legacyPro ? .pro : .free
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
            applyEntitlementsFromData(nil, uid: nil)
            return
        }

        await enforceTrialIfNeeded()

        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            if let data = snap.data() {
                applyEntitlementsFromData(data, uid: uid)
            } else {
                applyEntitlementsFromData(nil, uid: nil)
            }
        } catch {
            
            applyEntitlementsFromData(nil, uid: nil)
        }
    }

    // MARK: - Trial enforcement (30-day Pro trial)

    /// Rules:
    /// - If source == "stripe" => never trial
    /// - If tierOverride is set => no trial behavior
    /// - If tier != free => no trial behavior
    /// - If tier == free AND trialProvided != true AND trialStartedAt missing => start trial
    /// - If active and expired => end trial + revert to free
    /// - Warnings at 7/3/1 days left
    func enforceTrialIfNeeded() async {
        guard let uid = user?.uid else { return }
        let userRef = db.collection("users").document(uid)

        do {
            let snap = try await userRef.getDocument()
            guard let data = snap.data() else { return }

            // Stripe precedence: never trial again
            let source = (data["source"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if source == "stripe" {
                await MainActor.run {
                    self.shouldShowTrialStartModal = false
                    self.shouldShowTrialWarning = false
                    self.trialWarningDaysRemaining = nil
                }
                return
            }

            // Determine effective tier from Firestore (treat missing as free)
            let tierText = (data["tier"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let isFree = (tierText == nil || tierText == "free" || tierText == "")
            if !isFree {
                // Not free -> no trial behavior needed
                await MainActor.run {
                    self.shouldShowTrialWarning = false
                    self.trialWarningDaysRemaining = nil
                }
                return
            }

            let trialProvided = (data["trialProvided"] as? Bool) == true
            let status = (data["trialStatus"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let startedAt = data["trialStartedAt"] as? Timestamp
            let endsAt = data["trialEndsAt"] as? Timestamp

            // 1) Start trial if FREE and trialProvided is NOT true yet (first time ever)
            if trialProvided != true && startedAt == nil {
                let durationDays = 30
                let now = Date()
                let end = Calendar.current.date(byAdding: .day, value: durationDays, to: now)
                    ?? now.addingTimeInterval(30 * 86400)

                try await userRef.setData([
                    "trialProvided": true,
                    "trialStatus": "active",
                    "trialDurationDays": durationDays,
                    "trialStartedAt": FieldValue.serverTimestamp(),
                    "trialEndsAt": Timestamp(date: end),
                    "trialEndedAt": FieldValue.delete()
                ], merge: true)
                
               
                
               

                await MainActor.run {
                    self.shouldShowTrialStartModal = true
                    self.shouldShowTrialWarning = false
                    self.trialWarningDaysRemaining = nil
                }
                return
            }

            // 2) If active, enforce expiry + warning flags
            if status == "active", let endsAt {
                let now = Date()
                if now >= endsAt.dateValue() {
                    // Expire -> revert to Free (remove tier field)
                    try await userRef.setData([
                        "trialStatus": "ended",
                        "trialEndedAt": FieldValue.serverTimestamp()
                    ], merge: true)

                    await MainActor.run {
                        self.shouldShowTrialStartModal = false
                        self.shouldShowTrialWarning = false
                        self.trialWarningDaysRemaining = nil
                    }
                    return
                } else {
                    // Warning days: 7, 3, 1
                    let daysLeft = daysBetweenNowAnd(endsAt) ?? 0
                    let lastShown = (data["lastTrialWarningShown"] as? String)

                    var shouldWarn = false
                    var warningBucket: String? = nil

                    if daysLeft <= 7 && daysLeft >= 4 && lastShown != "7" {
                        shouldWarn = true
                        warningBucket = "7"
                    } else if daysLeft <= 3 && daysLeft >= 2 && lastShown != "3" {
                        shouldWarn = true
                        warningBucket = "3"
                    } else if daysLeft == 1 && lastShown != "1" {
                        shouldWarn = true
                        warningBucket = "1"
                    }

                    if shouldWarn, let bucket = warningBucket {
                        try await userRef.setData(
                            ["lastTrialWarningShown": bucket],
                            merge: true
                        )

                        // Show the BUCKET number (7 / 3 / 1) in the title — not the raw daysLeft.
                        let bucketDays: Int = Int(bucket) ?? daysLeft

                        await MainActor.run {
                            // ✅ Set the title data FIRST so SwiftUI has it when the alert is created.
                            self.trialWarningDaysRemaining = bucketDays
                            self.shouldShowTrialWarning = true
                        }
                    } else {
                        await MainActor.run {
                            self.shouldShowTrialWarning = false
                            self.trialWarningDaysRemaining = nil
                        }
                    }
                }
            }
        } catch {
           
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
               
            }
        } catch {
             

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
             
        }
    }

    /// Upsert users/{uid} with displayName/emailLower/**photoUrl** (canonical), without touching `pro`.
    /// Also deletes legacy `photoURL` if present to avoid duplicates.
    func upsertUserDoc(name: String, email: String, photoURLString: String?) async {
        let uid = user?.uid ?? Auth.auth().currentUser?.uid
        guard let uid else { return }

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
             
        }
    }

    /// Generic merge helper (optional use).
    func mergeUserDoc(fields: [String: Any]) async {
        guard let uid = user?.uid else { return }
        do {
            try await db.collection("users").document(uid).setData(fields, merge: true)
        } catch {
             
        }
    }

    // MARK: - Leaderboard totals sync (phone → Firestore)

    /// Sync leaderboard totals in Firestore from the device's current local view
    /// (7 / 30 / 60-day totals). Phone is the source of truth; Firestore is just a snapshot.
    func syncTotalsFromLocal(_ totals: TripleWindow) async {
        guard let uid = user?.uid else { return }

        do {
            try await db.collection("users").document(uid).setData([
                "total7": totals.d7,
                "total30": totals.d30,
                "total60": totals.d60,
                "updatedAt": Timestamp(date: Date())
            ], merge: true)
        } catch {
             
        }
    }

    // MARK: - Daily /daily/yyyyMMdd sync (phone → Firestore)

    /// Step 2 helper called by DailyView checkbox toggles.
    /// Writes users/{uid}/daily/{yyyyMMdd} { completed: [String], updatedAt: serverTimestamp() }
    func uploadTodayDailyFromLocal(store: HabitStore) async {
        guard let uid = user?.uid else { return }

        // Must match StatsView/DailyView key format used in UserDefaults snapshots
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.dateFormat = "yyyyMMdd"
        let todayKey = df.string(from: Date())

        // Prefer UserDefaults snapshot (consistent with your rolling windows),
        // but fall back to live store.completed if snapshot isn't there yet.
        let snap = UserDefaults.standard.array(forKey: "daily_completed_\(todayKey)") as? [String]
        let completedSet = Set(snap ?? Array(store.completed))

        let docRef = db
            .collection("users")
            .document(uid)
            .collection("daily")
            .document(todayKey)

        do {
            try await docRef.setData([
                "completed": Array(completedSet),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
             
        }
    }

    // MARK: - Daily toggle sync (Android parity)

    /// Call this immediately after a DailyView checkbox toggle.
    /// 1) Snapshots today's completed to UserDefaults (yyyyMMdd)
    /// 2) Uploads users/{uid}/daily/{yyyyMMdd}
    /// 3) Computes rolling totals (7/30/60) from UserDefaults snapshots
    /// 4) Syncs totals to users/{uid} (total7/total30/total60)
    func syncAfterDailyToggle(store: HabitStore) async {
        guard user?.uid != nil else { return }

        // 1) Snapshot today's completed set to UserDefaults (yyyyMMdd)
        let cal = Calendar(identifier: .gregorian)
        let df = DateFormatter()
        df.calendar = cal
        df.dateFormat = "yyyyMMdd"
        let todayKey = df.string(from: Date())

        UserDefaults.standard.set(Array(store.completed), forKey: "daily_completed_\(todayKey)")

        // 2) Upload daily doc
        await uploadTodayDailyFromLocal(store: store)

        // 3) Compute totals from UserDefaults snapshots + live today fallback
        let totals = computeLocalTotalsForCurrentUser(store: store)

        // 4) Sync totals to Firestore
        await syncTotalsFromLocal(totals)
    }

    /// Same algorithm you use in StatsView, moved here so DailyView can use it too.
    private func computeLocalTotalsForCurrentUser(store: HabitStore) -> TripleWindow {
        let physId = "pillar_phys"
        let pietyId = "pillar_piety"
        let peopleId = "pillar_people"
        let prodId = "pillar_prod"

        func lastNDateKeys(_ n: Int) -> [String] {
            let cal = Calendar(identifier: .gregorian)
            let df = DateFormatter()
            df.calendar = cal
            df.dateFormat = "yyyyMMdd"
            return (0..<n).compactMap { i in
                guard let d = cal.date(byAdding: .day, value: -i, to: Date()) else { return nil }
                return df.string(from: d)
            }
        }

        func todayKey() -> String {
            let df = DateFormatter()
            df.calendar = Calendar(identifier: .gregorian)
            df.dateFormat = "yyyyMMdd"
            return df.string(from: Date())
        }

        func perDayCompletedOrLive(_ dateKey: String) -> Set<String> {
            if let snap = UserDefaults.standard.array(forKey: "daily_completed_\(dateKey)") as? [String] {
                return Set(snap)
            }
            if dateKey == todayKey() {
                return store.completed
            }
            return []
        }

        func dayHasAllFourPs(_ perDay: Set<String>) -> Bool {
            perDay.contains(physId) &&
            perDay.contains(pietyId) &&
            perDay.contains(peopleId) &&
            perDay.contains(prodId)
        }

        func countAll4PInLastNDays(_ n: Int) -> Int {
            lastNDateKeys(n).reduce(0) { acc, key in
                let s = perDayCompletedOrLive(key)
                return acc + ((!s.isEmpty && dayHasAllFourPs(s)) ? 1 : 0)
            }
        }

        func countPillarInLastNDays(flag: String, n: Int) -> Int {
            lastNDateKeys(n).reduce(0) { acc, key in
                let s = perDayCompletedOrLive(key)
                return acc + (s.contains(flag) ? 1 : 0)
            }
        }

        let all4_7   = countAll4PInLastNDays(7)
        let phys_7   = countPillarInLastNDays(flag: physId, n: 7)
        let piety_7  = countPillarInLastNDays(flag: pietyId, n: 7)
        let people_7 = countPillarInLastNDays(flag: peopleId, n: 7)
        let prod_7   = countPillarInLastNDays(flag: prodId, n: 7)

        let all4_30   = countAll4PInLastNDays(30)
        let phys_30   = countPillarInLastNDays(flag: physId, n: 30)
        let piety_30  = countPillarInLastNDays(flag: pietyId, n: 30)
        let people_30 = countPillarInLastNDays(flag: peopleId, n: 30)
        let prod_30   = countPillarInLastNDays(flag: prodId, n: 30)

        let all4_60   = countAll4PInLastNDays(60)
        let phys_60   = countPillarInLastNDays(flag: physId, n: 60)
        let piety_60  = countPillarInLastNDays(flag: pietyId, n: 60)
        let people_60 = countPillarInLastNDays(flag: peopleId, n: 60)
        let prod_60   = countPillarInLastNDays(flag: prodId, n: 60)

        let total7  = all4_7  + phys_7  + piety_7  + people_7  + prod_7
        let total30 = all4_30 + phys_30 + piety_30 + people_30 + prod_30
        let total60 = all4_60 + phys_60 + piety_60 + people_60 + prod_60

        return TripleWindow(d7: total7, d30: total30, d60: total60)
    }

    // MARK: - Trial helpers

    private func daysBetweenNowAnd(_ future: Timestamp?) -> Int? {
        guard let future else { return nil }
        let seconds = future.dateValue().timeIntervalSince(Date())
        let days = Int(ceil(seconds / 86400.0))
        return max(days, 0)
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
