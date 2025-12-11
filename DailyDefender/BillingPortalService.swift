/*import Foundation
import FirebaseAuth
import UIKit

/// Errors the Billing Portal service can throw.
enum BillingPortalError: LocalizedError {
    case notSignedIn
    case invalidURL
    case server(code: String, message: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "You need to be signed in to manage your subscription."
        case .invalidURL:
            return "Billing portal URL is invalid."
        case .server(let code, let message):
            return "[\(code)] \(message)"
        case .invalidResponse:
            return "Unexpected response from billing portal."
        }
    }
}

/// Response shape from your Cloud Function on success.
private struct BillingPortalSuccess: Decodable {
    let url: String
}

/// Response shape from your Cloud Function on error.
private struct BillingPortalFailure: Decodable {
    let error: String
    let message: String
}

/// Singleton service used by SubscriptionManagementCard
/// to open the Stripe Billing Portal.
final class BillingPortalService {

    static let shared = BillingPortalService()
    private init() {}

    /// Call the Firebase HTTPS function to create a Stripe
    /// Billing Portal session and open it in Safari.
    ///
    /// - Parameter returnURL: Where Stripe sends user back after managing billing.
    func openBillingPortal(returnURL: String) async throws {
        // 1) Ensure we have a signed-in Firebase user
        guard let user = Auth.auth().currentUser else {
            throw BillingPortalError.notSignedIn
        }

        // 2) Get a fresh ID token for Authorization header
        let idToken: String = try await withCheckedThrowingContinuation { cont in
            user.getIDTokenForcingRefresh(true) { token, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else if let token = token {
                    cont.resume(returning: token)
                } else {
                    cont.resume(throwing: BillingPortalError.notSignedIn)
                }
            }
        }

        // 3) Build request to your Cloud Function
        guard let url = URL(string: "https://managebillingportal-4r7i4rq24a-uc.a.run.app") else {
            throw BillingPortalError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = ["returnURL": returnURL]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // 4) Execute request
        let (data, response) = try await URLSession.shared.data(for: request)

        // 5) Handle HTTP status codes
        guard let http = response as? HTTPURLResponse else {
            throw BillingPortalError.invalidResponse
        }

        if http.statusCode != 200 {
            // Try to decode our { error, message } JSON
            if let failure = try? JSONDecoder().decode(BillingPortalFailure.self, from: data) {
                throw BillingPortalError.server(code: failure.error, message: failure.message)
            } else {
                throw BillingPortalError.invalidResponse
            }
        }

        // 6) Decode success JSON → { url }
        let success = try JSONDecoder().decode(BillingPortalSuccess.self, from: data)

        guard let portalURL = URL(string: success.url) else {
            throw BillingPortalError.invalidURL
        }

        // 7) Open in Safari
        await MainActor.run {
            UIApplication.shared.open(portalURL, options: [:], completionHandler: nil)
        }
    }
}*/
