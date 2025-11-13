import Foundation
import FirebaseFirestore

enum FirestoreSeeder {
    static func seedOrMergeUser(
        db: Firestore,
        uid: String,
        email: String,
        displayName: String?,
        photoURL: String?
    ) async {
        let userRef = db.collection("users").document(uid)

        do {
            let existing = try await userRef.getDocument()
            var toMerge: [String: Any] = [
                "email": email,
                "emailLower": email.lowercased(),
                "displayName": displayName ?? "",
                "photoUrl": photoURL ?? "",
                "updatedAt": FieldValue.serverTimestamp()
            ]
            if !existing.exists {
                toMerge["createdAt"] = FieldValue.serverTimestamp()
            }

            // Idempotent default counters / fields (only set if missing)
            func putIfMissing(_ key: String, _ value: Any) {
                if existing.get(key) == nil { toMerge[key] = value }
            }
            putIfMissing("journalTotal", 0)
            putIfMissing("journal7d", 0)
            putIfMissing("journal30d", 0)
            putIfMissing("all4pTotal", 0)
            putIfMissing("all4p7d", 0)
            putIfMissing("all4p30d", 0)
            putIfMissing("streakCurrent", 0)
            putIfMissing("streakBest", 0)
            putIfMissing("lastAll4pDay", "")
            putIfMissing("lastJournalDay", "")
            putIfMissing("role", "member")
            putIfMissing("squadId", "")

            // First write: merge base profile + counters
            try await userRef.setData(toMerge, merge: true)

            // Second write: sync tier from allowlist, if present (mirrors Android behavior)
            do {
                let emailLower = email.lowercased()
                let allowRef = db.collection("allowlist").document(emailLower)
                let allowSnap = try await allowRef.getDocument()

                if let allowData = allowSnap.data(),
                   let allowTier = (allowData["tier"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !allowTier.isEmpty {
                    try await userRef.updateData(["tier": allowTier])
                    #if DEBUG
                    print("Seeder: tier sync succeeded from allowlist: \(allowTier)")
                    #endif
                } else {
                    #if DEBUG
                    print("Seeder: allowlist doc missing or no tier for \(emailLower)")
                    #endif
                }
            } catch {
                #if DEBUG
                print("Seeder: tier sync skipped/failed (likely not on allowlist): \(error.localizedDescription)")
                #endif
            }
        } catch {
            #if DEBUG
            print("Seeder: failed with error \(error.localizedDescription)")
            #endif
        }
    }
}
