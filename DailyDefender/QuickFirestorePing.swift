import Foundation
import FirebaseFirestore
import FirebaseAuth

enum QuickFirestorePing {
    static func run(label: String = "ios-ping") {
        let db = Firestore.firestore()
        guard let uid = Auth.auth().currentUser?.uid else {
            print("PING: no auth user"); return
        }
        let doc = db.collection("_debugPing").document(uid)
        let payload: [String: Any] = [
            "at": FieldValue.serverTimestamp(),
            "label": label,
            "bundle": Bundle.main.bundleIdentifier ?? "unknown"
        ]
        doc.setData(payload, merge: true) { err in
            if let err = err as NSError? {
                print("PING ERROR:", err.code, err.localizedDescription)
            } else {
                print("PING OK for", uid)
            }
        }
    }
}
