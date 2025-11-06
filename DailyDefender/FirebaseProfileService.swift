import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

enum ProfileUpdateError: Error {
    case noUser
    case invalidLocalPhotoPath
}

final class FirebaseProfileService {

    /// Uploads the local photo (if provided), updates Auth profile displayName/photoURL,
    /// and merges these fields into Firestore `users/{uid}`.
    @discardableResult
    static func updateProfile(displayName: String,
                              localPhotoPath: String?,
                              db: Firestore) async throws -> URL? {

        guard let user = Auth.auth().currentUser else {
            throw ProfileUpdateError.noUser
        }

        // 1) Upload photo if we have a local path
        var downloadURL: URL? = nil
        if let path = localPhotoPath, !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw ProfileUpdateError.invalidLocalPhotoPath
            }

            let storageRef = Storage.storage().reference()
            let photoRef  = storageRef.child("profilePhotos/\(user.uid).jpg")

            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"

            try await putFileAsync(ref: photoRef, fileURL: url, metadata: metadata)
            downloadURL = try await photoRef.downloadURL()
        }

        // 2) Update Firebase Auth profile (displayName + photoURL)
        try await commitAuthProfileChange(user: user,
                                          displayName: displayName,
                                          photoURL: downloadURL)

        // 3) Merge into Firestore `users/{uid}`
        var payload: [String: Any] = [
            "displayName": displayName,
            "updatedAt": Timestamp(date: Date())
        ]
        if let downloadURL {
            payload["photoURL"] = downloadURL.absoluteString
        }

        try await db.collection("users").document(user.uid).setData(payload, merge: true)
        return downloadURL
    }

    // MARK: - Private async helpers

    private static func putFileAsync(ref: StorageReference,
                                     fileURL: URL,
                                     metadata: StorageMetadata?) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ref.putFile(from: fileURL, metadata: metadata) { _, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: ())
                }
            }
        }
    }

    private static func commitAuthProfileChange(user: User,
                                                displayName: String,
                                                photoURL: URL?) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let change = user.createProfileChangeRequest()
            change.displayName = displayName
            if let photoURL { change.photoURL = photoURL }
            change.commitChanges { error in
                if let error = error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: ())
                }
            }
        }
    }
}
