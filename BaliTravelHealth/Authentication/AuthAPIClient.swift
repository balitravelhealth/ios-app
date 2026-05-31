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

        switch await BaliAuthAPIClient.shared.validateSession() {
        case .valid: return .valid
        case .invalid: return .invalid
        case .unknown: return .unknown
        }
    }

    // MARK: - Private

    private func post(action _: String,
                      provider _: AuthProvider,
                      providerUserID _: String,
                      identityToken _: String,
                      email _: String?,
                      name _: String?) async throws -> ServerSession {
        throw AuthAPIError.server(
            status: 501,
            message: "Traveler accounts currently support Google sign-in through the production Gateway."
        )
    }
}
