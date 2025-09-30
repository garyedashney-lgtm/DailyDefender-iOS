import Foundation
import OSLog

// Mirror of your Android sealed class
enum MailchimpResult {
    case subscribed
    case pendingDoubleOptIn
    case alreadySubscribed
    case failure(String)

    var ok: Bool {
        switch self {
        case .failure: return false
        default: return true
        }
    }

    var message: String {
        switch self {
        case .subscribed:
            return "Subscribed to Wallace's updates."
        case .pendingDoubleOptIn:
            return "Check your email to confirm your subscription."
        case .alreadySubscribed:
            return "You're already on the list."
        case .failure(let m):
            return m
        }
    }
}

enum MailchimpService {
    // Match Android exactly
    private static let SEND_NAMES = true
    private static let BASE_URL = "https://advisortomen.us20.list-manage.com/subscribe/post"
    private static let U = "712af5198f008320ace0cb304"
    private static let ID = "3a8c90fbd6"
    private static let F_ID = "00d559eef0"
    private static let TAGS = "4254854" // same numeric tag id you used on Android

    // iOS UA, analogous to your Android UA
    private static let userAgent = "DailyDefenderiOS/1.0"
    private static let log = Logger(subsystem: "DailyDefender", category: "Mailchimp")

    // Public API — same signature as Android (no tags argument; tags are internal constant)
    static func subscribe(email: String, firstName: String? = nil, lastName: String? = nil) async -> MailchimpResult {
        // Basic sanity check to avoid round-trips with obviously bad emails
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            return .failure("Invalid email address.")
        }

        // Build x-www-form-urlencoded body
        var fields: [String: String] = [
            "u": U,
            "id": ID,
            "f_id": F_ID,
            "EMAIL": trimmedEmail,
            "tags": TAGS
        ]
        if SEND_NAMES {
            fields["FNAME"] = firstName ?? ""
            fields["LNAME"] = lastName ?? ""
        } else {
            fields["FNAME"] = ""
            fields["LNAME"] = ""
        }

        guard let url = URL(string: BASE_URL) else {
            return .failure("Invalid URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = formURLEncoded(fields).data(using: .utf8)

        // Reasonable timeouts to match Android’s behavior
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 20
        let session = URLSession(configuration: config)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure("Network error. Try again.")
            }
            let statusCode = http.statusCode
            guard (200...299).contains(statusCode) else {
                return .failure("Network error (\(statusCode)). Try again.")
            }

            // Mailchimp returns HTML—normalize + lower-case like Android does
            let raw = String(data: data, encoding: .utf8) ?? ""
            let normalized = raw
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .lowercased()

            // Uncomment for debugging if needed (then remove)
            // log.debug("Mailchimp HTML (prefix): \(String(normalized.prefix(200)))")

            // Same phrase checks as Android (+ a few extra variants)
            if normalized.contains("already subscribed")
                || normalized.contains("is already subscribed")
                || normalized.contains("already a subscriber") {
                return .alreadySubscribed

            } else if normalized.contains("almost finished")
                        || normalized.contains("confirm your email")
                        || normalized.contains("confirm your subscription")
                        || normalized.contains("pending") {
                return .pendingDoubleOptIn

            } else if normalized.contains("thank you for subscribing")
                        || normalized.contains("subscription confirmed")
                        || normalized.contains("successfully subscribed")
                        || normalized.contains("thank you for signing up") {
                return .subscribed

            } else if normalized.contains("too many subscribe attempts") {
                return .failure("Too many attempts. Try later.")

            } else {
                // Copy can vary; treat 200 as success when unknown (Android behavior)
                return .subscribed
            }
        } catch {
            return .failure("Network error: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    // Proper application/x-www-form-urlencoded encoding:
    // - Spaces => '+'
    // - '+', '&', '=' must be percent-escaped
    private static func formURLEncoded(_ fields: [String: String]) -> String {
        func encode(_ s: String) -> String {
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: "+&=")
            let percent = s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
            return percent.replacingOccurrences(of: " ", with: "+")
        }
        return fields.map { "\(encode($0.key))=\(encode($0.value))" }
                     .joined(separator: "&")
    }
}
