import Foundation

extension Bundle {
    var appVersion: String { (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0" }
    var appBuild: String { (infoDictionary?["CFBundleVersion"] as? String) ?? "1" }
}
