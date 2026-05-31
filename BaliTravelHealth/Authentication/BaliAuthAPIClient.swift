import Foundation

// Response from POST /auth/google and POST /auth/refresh
struct BaliSession: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: BaliSessionUser?

    struct BaliSessionUser: Decodable, Sendable {
        let id: Int
        let email: String
    }
}

struct BaliAuthAPIClient: Sendable {
    static let shared = BaliAuthAPIClient()

    enum SessionValidity: Sendable {
        case valid
        case invalid
        case unknown
    }

    // POST /auth/google
    func signInWithGoogle(idToken: String) async throws -> BaliSession {
        var req = BaliAPI.request("auth/google", method: "POST")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "id_token": idToken,
            "device_info": BaliAPI.deviceInfo()
        ])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw BaliAPIError.malformedResponse
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw BaliAPIError.server(
                status: http.statusCode,
                message: Self.googleSignInMessage(from: data)
            )
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BaliAPIError.from(data: data, status: http.statusCode)
        }
        return try BaliAPI.decode(BaliSession.self, from: data)
    }

    // POST /auth/refresh — returns true if a new token was stored, false if no refresh token on device.
    @discardableResult
    func refreshToken() async throws -> Bool {
        guard let storedRefresh = KeychainManager.shared.get(.refreshToken) else {
            return false
        }

        var req = BaliAPI.request("auth/refresh", method: "POST")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "refresh_token": storedRefresh,
            "device_info": BaliAPI.deviceInfo()
        ])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw BaliAPIError.malformedResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BaliAPIError.from(data: data, status: http.statusCode)
        }

        let refreshed = try BaliAPI.decode(BaliRefreshResponse.self, from: data)
        storeTokens(accessToken: refreshed.accessToken, refreshToken: refreshed.refreshToken, expiresIn: refreshed.expiresIn)
        return true
    }

    // POST /auth/logout — best-effort; errors are silently ignored.
    func logout() async {
        guard let refreshToken = KeychainManager.shared.get(.refreshToken) else { return }
        var req = BaliAPI.request("auth/logout", method: "POST")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])
        _ = try? await URLSession.shared.data(for: req)
    }

    func validateSession() async -> SessionValidity {
        guard KeychainManager.shared.get(.sessionToken) != nil else {
            return .invalid
        }

        let req = BaliAPI.authedRequest("traveler-profile")
        do {
            let (data, status) = try await BaliAPI.perform(req)
            if (200..<300).contains(status) || status == 404 || status == 204 || data.isEmpty {
                return .valid
            }
            if status == 401 || status == 403 {
                return .invalid
            }
            return .unknown
        } catch BaliAPIError.unauthorized {
            return .invalid
        } catch {
            return .unknown
        }
    }

    func storeTokens(accessToken: String, refreshToken: String, expiresIn: Int) {
        let kc = KeychainManager.shared
        kc.save(accessToken, for: .sessionToken)
        kc.save(refreshToken, for: .refreshToken)
        let expiry = Date().addingTimeInterval(TimeInterval(expiresIn)).timeIntervalSince1970
        kc.save(String(expiry), for: .accessTokenExpiresAt)
    }

    private struct BaliRefreshResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Int
    }

    private static func googleSignInMessage(from data: Data) -> String {
        let fallback = "Google sign-in could not be verified. Please try again."
        guard let message = serverMessage(from: data), !message.isEmpty else {
            return fallback
        }

        if message.localizedCaseInsensitiveContains("authentication failed") {
            return fallback
        }
        return message
    }

    private static func serverMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object["error"] as? String
            ?? object["message"] as? String
    }
}
