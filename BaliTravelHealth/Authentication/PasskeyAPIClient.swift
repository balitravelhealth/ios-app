import Foundation

/// Server contract for WebAuthn / Passkey flows.
///
/// Two endpoints, both POST JSON:
///
/// 1. `POST /internal/passkey/begin`
///    Returns a `PasskeyBeginResponse` containing both a registration challenge
///    (for new accounts) and a login challenge (for existing ones). The client
///    feeds *both* to `ASAuthorizationController`; iOS picks the right path.
///
/// 2. `POST /internal/passkey/finish`
///    Accepts either a registration or assertion payload (`type` discriminator).
///    Returns `ServerSession` on success. **401** = the server couldn't verify
///    the credential. The client treats 401 as a hard sign-in failure and the
///    user is *not* allowed past the login screen.
struct PasskeyAPIClient: Sendable {
    static let shared = PasskeyAPIClient()

    /// TODO: replace with your real passkey base URL.
    var baseURL: URL = URL(string: "https://balihealth.me/internal/passkey")!

    // MARK: - Begin

    struct BeginResponse: Decodable {
        let rpId: String
        let registrationChallenge: String        // base64url
        let registrationUserId: String           // base64url, opaque server-generated
        let registrationDisplayName: String      // shown in the Passkey sheet
        let loginChallenge: String               // base64url
    }

    func begin() async throws -> BeginResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("begin"))
        request.httpMethod = "POST"
        request.applyAppUserAgent()
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: [String: Any]())

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AuthAPIError.malformedResponse
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw AuthAPIError.server(status: http.statusCode, message: "Server rejected the sign-in request.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AuthAPIError.server(status: http.statusCode, message: serverMessage(data) ?? "Server error.")
        }
        return try JSONDecoder().decode(BeginResponse.self, from: data)
    }

    // MARK: - Finish

    /// Send the credential collected by `ASAuthorizationController` to the
    /// server for verification.
    func finishRegistration(
        credentialID: Data,
        attestationObject: Data,
        clientDataJSON: Data
    ) async throws -> ServerSession {
        try await postFinish(payload: [
            "type": "registration",
            "credentialId": credentialID.base64URLEncodedString(),
            "attestationObject": attestationObject.base64URLEncodedString(),
            "clientDataJSON": clientDataJSON.base64URLEncodedString(),
        ])
    }

    func finishAssertion(
        credentialID: Data,
        authenticatorData: Data,
        clientDataJSON: Data,
        signature: Data,
        userHandle: Data?
    ) async throws -> ServerSession {
        var payload: [String: Any] = [
            "type": "assertion",
            "credentialId": credentialID.base64URLEncodedString(),
            "authenticatorData": authenticatorData.base64URLEncodedString(),
            "clientDataJSON": clientDataJSON.base64URLEncodedString(),
            "signature": signature.base64URLEncodedString(),
        ]
        if let userHandle {
            payload["userHandle"] = userHandle.base64URLEncodedString()
        }
        return try await postFinish(payload: payload)
    }

    // MARK: - Private

    private func postFinish(payload: [String: Any]) async throws -> ServerSession {
        var request = URLRequest(url: baseURL.appendingPathComponent("finish"))
        request.httpMethod = "POST"
        request.applyAppUserAgent()
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AuthAPIError.malformedResponse
        }
        // 401 → bubble up; AuthenticationManager turns this into `.unauthorized`
        // and the user is blocked from continuing past the login screen.
        if http.statusCode == 401 || http.statusCode == 403 {
            throw AuthAPIError.server(status: http.statusCode, message: "Server rejected your passkey.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AuthAPIError.server(status: http.statusCode, message: serverMessage(data) ?? "Server error.")
        }
        do {
            return try JSONDecoder().decode(ServerSession.self, from: data)
        } catch {
            throw AuthAPIError.malformedResponse
        }
    }

    private func serverMessage(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj["error"] as? String ?? obj["message"] as? String
    }
}
