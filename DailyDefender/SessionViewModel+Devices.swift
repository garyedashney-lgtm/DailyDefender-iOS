import Foundation
import FirebaseAuth
import FirebaseFirestore
import UIKit

extension SessionViewModel {
    /// Register / update this install as one of the user's devices in Firestore.
    func registerCurrentDevice() async {
        guard let uid = user?.uid else { return }

        let db = self.db
        let deviceId = DeviceIdProvider.shared.deviceId

        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

        let data: [String: Any] = [
            "deviceId": deviceId,
            "platform": "ios",
            "model": device.model,
            "systemName": device.systemName,
            "systemVersion": device.systemVersion,
            "appVersion": appVersion,
            "updatedAt": FieldValue.serverTimestamp(),
            "createdAt": FieldValue.serverTimestamp()
        ]

        try? await db.collection("users")
            .document(uid)
            .collection("devices")
            .document(deviceId)
            .setData(data, merge: true)
    }
}

