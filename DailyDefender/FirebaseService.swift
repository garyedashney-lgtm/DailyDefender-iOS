import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

final class FirebaseService {
    static let shared = FirebaseService()
    private(set) var configured = false

    private init() {}

    func configureIfNeeded() {
        guard !configured else { return }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        configured = true

        // 🔎 Print the *actual* config the app is using at runtime
        if let app = FirebaseApp.app() {
            let o = app.options
            print("FB CONFIG →",
                  "projectID=\(o.projectID ?? "nil")",
                  "apiKey=\(o.apiKey)",
                  "bundleID=\(Bundle.main.bundleIdentifier ?? "nil")",
                  "gcmSenderID=\(o.gcmSenderID ?? "nil")")
        } else {
            print("FB CONFIG → FirebaseApp.app() is nil ❌")
        }

        // Firestore settings are optional but fine to set
        let db = Firestore.firestore()
        let settings = db.settings
        settings.isPersistenceEnabled = true
        db.settings = settings
    }

    var db: Firestore {
        Firestore.firestore()
    }
}

