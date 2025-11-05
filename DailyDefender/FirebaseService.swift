// FirebaseService.swift
import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

final class FirebaseService {
    static let shared = FirebaseService()
    private(set) var db: Firestore!

    private init() {}

    func configureIfNeeded() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        Firestore.firestore().settings = settings
        self.db = Firestore.firestore()
    }
}

