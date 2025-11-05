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

            try await userRef.setData(toMerge, merge: true)

            // Second write: attempt pro=true (rules will allow only if on allowlist)
            do {
                try await userRef.updateData(["pro": true])
                #if DEBUG
                print("Seeder: pro promotion succeeded (allowlist ok)")
                #endif
            } catch {
                #if DEBUG
                print("Seeder: pro promotion rejected by rules (expected for non-allowlisted)")
                #endif
            }
        } catch {
            #if DEBUG
            print("Seeder: failed with error \(error.localizedDescription)")
            #endif
        }
    }
}
