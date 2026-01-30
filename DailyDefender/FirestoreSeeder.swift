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
            // 1) Load existing doc (if any)
            let existing = try await userRef.getDocument()

            // 2) Base merge: profile + bookkeeping
            var toMerge: [String: Any] = [
                "email": email,
                "emailLower": email.lowercased(),
                "displayName": displayName ?? "",
                "photoUrl": photoURL ?? "",
                "updatedAt": FieldValue.serverTimestamp()
            ]

            if !existing.exists {
                toMerge["createdAt"] = FieldValue.serverTimestamp()
                // trialProvided means "trial has already been used/consumed"
                toMerge["trialProvided"] = false
            }

            // Idempotent default counters / fields (only set if missing)
            func putIfMissing(_ key: String, _ value: Any) {
                if existing.get(key) == nil {
                    toMerge[key] = value
                }
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

            // 3) Allowlist → ONLY seed tier on *first* creation
            //
            //    - Purpose: pre-load BOD / manual / pre-login Stripe users
            //    - After the user doc exists, tier is owned by:
            //        • Stripe webhooks (for subscribers)
            //        • Admin edits (for BOD / manual grants)
            //
            //    So we explicitly *skip* allowlist tier sync if the doc already existed.
            guard !existing.exists else {
                
                return
            }

            // New user doc → check allowlist once
            do {
                let emailLower = email.lowercased()
                guard !emailLower.isEmpty else {
                
                    return
                }

                let allowRef = db.collection("allowlist").document(emailLower)
                let allowSnap = try await allowRef.getDocument()

                guard let allowData = allowSnap.data() else {
                 
                    return
                }

                var update: [String: Any] = [:]

                if let allowTierRaw = allowData["tier"] as? String {
                    let allowTier = allowTierRaw
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !allowTier.isEmpty {
                        update["tier"] = allowTier
                        update["trialProvided"] = false
                    }
                }

                if let source = allowData["source"] as? String,
                   !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    update["source"] = source
                }

                // Optional: mirror old `pro` flag for allowlist-pro users
                if let allowTier = update["tier"] as? String,
                   allowTier.lowercased() == "pro" {
                    update["pro"] = true
                }

                if !update.isEmpty {
                    try await userRef.updateData(update)
                   
                } else {
                    
                }
            } catch {
                
            }
        } catch {
            
        }
    }
}
