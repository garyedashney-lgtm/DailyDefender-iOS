import Foundation
import UIKit

// MARK: - One-account-per-device binding

final class DeviceBindingManager {
    static let shared = DeviceBindingManager()
    private let key = "mm_boundAuthUid"

    private init() {}

    var boundUid: String? {
        get {
            UserDefaults.standard.string(forKey: key)
        }
        set {
            let defaults = UserDefaults.standard
            if let value = newValue {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }
}

// MARK: - Per-install deviceId

final class DeviceIdProvider {
    static let shared = DeviceIdProvider()
    private let key = "mm_deviceId"

    let deviceId: String

    private init() {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: key) {
            deviceId = existing
        } else {
            let new = UUID().uuidString
            deviceId = new
            defaults.set(new, forKey: key)
        }
    }
}
