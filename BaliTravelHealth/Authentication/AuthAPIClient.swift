import Foundation

struct ServerSession: Decodable {
    let sessionToken: String
    let refreshToken: String?
    let userID: String
    let name: String?
    let email: String?
    let isNewUser: Bool?
}

enum AuthProvider: String, Codable, Sendable {
    case apple
    case google
    case passkey
}

enum AuthAPIError: Error, LocalizedError {
    case userNotFound
    case alreadyRegistered
    case server(status: Int, message: String)
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .userNotFound: return "Account not found"
        case .alreadyRegistered: return "Account already exists"
        case .server(_, let message): return message
        case .malformedResponse: return "Malformed server response"
        }
    }
}

struct AuthAPIClient: Sendable {
    static let shared = AuthAPIClient()

    /// Try to sign in with the given provider credentials.
    /// Throws `AuthAPIError.userNotFound` if the account does not exist yet.
    func signIn(provider: AuthProvider,
                providerUserID: String,
                identityToken: String,
                email: String?,
                name: String?) async throws -> ServerSession {
        try await post(
            action: "signin",
            provider: provider,
            providerUserID: providerUserID,
            identityToken: identityToken,
            email: email,
            name: name
        )
    }

    /// Register a new account with the given provider credentials.
    /// Throws `AuthAPIError.alreadyRegistered` if the account already exists.
    func signUp(provider: AuthProvider,
                providerUserID: String,
                identityToken: String,
                email: String?,
                name: String?) async throws -> ServerSession {
        try await post(
            action: "signup",
            provider: provider,
            providerUserID: providerUserID,
            identityToken: identityToken,
            email: email,
            name: name
        )
    }

    /// Sign in if the account exists, otherwise sign up. Either way returns a session.
    func signInOrSignUp(provider: AuthProvider,
                        providerUserID: String,
                        identityToken: String,
                        email: String?,
                        name: String?) async throws -> ServerSession {
        do {
            return try await signIn(
                provider: provider,
                providerUserID: providerUserID,
                identityToken: identityToken,
                email: email,
                name: name
            )
        } catch AuthAPIError.userNotFound {
            return try await signUp(
                provider: provider,
                providerUserID: providerUserID,
                identityToken: identityToken,
                email: email,
                name: name
            )
        } catch AuthAPIError.alreadyRegistered {
            return try await signIn(
                provider: provider,
                providerUserID: providerUserID,
                identityToken: identityToken,
                email: email,
                name: name
            )
        }
    }

    /// Outcome of a session-validation probe.
    ///
    /// - `valid`: server clearly recognised the token (2xx).
    /// - `invalid`: server clearly rejected the token (401/403). Only this
    ///   case should cause a forced sign-out — any other response means we
    ///   couldn't tell, and the locally-stored token is still our best guess.
    /// - `unknown`: network error, 404/405/5xx, malformed reply, etc.
    enum SessionValidity {
        case valid
        case invalid
        case unknown
    }

    func validate(sessionToken: String) async -> SessionValidity {
        if AppFlags.useDummyData {
            return .valid                       // accept the local test token
        }

        var request = URLRequest(url: AuthConfig.sessionEndpoint)
        request.httpMethod = "GET"
        request.applyAppUserAgent()
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .unknown }
            if (200..<300).contains(http.statusCode) { return .valid }
            if http.statusCode == 401 || http.statusCode == 403 { return .invalid }
            return .unknown
        } catch {
            return .unknown
        }
    }

    // MARK: - Private

    private func post(action: String,
                      provider: AuthProvider,
                      providerUserID: String,
                      identityToken: String,
                      email: String?,
                      name: String?) async throws -> ServerSession {
        var request = URLRequest(url: AuthConfig.sessionEndpoint)
        request.httpMethod = "POST"
        request.applyAppUserAgent()
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload: [String: Any?] = [
            "action": action,
            "provider": provider.rawValue,
            "providerUserId": providerUserID,
            "identityToken": identityToken,
            "email": email,
            "name": name
        ]
        request.httpBody = try JSONSerialization.data(
            withJSONObject: payload.compactMapValues { $0 }
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AuthAPIError.malformedResponse
        }

        if (200..<300).contains(http.statusCode) {
            return try JSONDecoder().decode(ServerSession.self, from: data)
        }

        let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let code = (body?["code"] as? String) ?? ""
        let message = (body?["error"] as? String)
            ?? (body?["message"] as? String)
            ?? String(data: data, encoding: .utf8)
            ?? "Request failed"

        switch (http.statusCode, code) {
        case (404, _), (_, "user_not_found"), (_, "not_registered"):
            throw AuthAPIError.userNotFound
        case (409, _), (_, "already_registered"), (_, "user_exists"):
            throw AuthAPIError.alreadyRegistered
        default:
            throw AuthAPIError.server(status: http.statusCode, message: message)
        }
    }
}
