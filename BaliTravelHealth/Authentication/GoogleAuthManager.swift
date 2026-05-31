import Foundation
import AuthenticationServices
import CryptoKit

struct GoogleProfile: Sendable {
    let sub: String
    let email: String?
    let name: String?
    let idToken: String
    let accessToken: String
    let refreshToken: String?
}

enum GoogleAuthError: Error, LocalizedError {
    case cancelled
    case invalidResponse
    case tokenExchangeFailed(String)
    case profileDecodeFailed

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Sign-in cancelled"
        case .invalidResponse: return "Invalid response from Google"
        case .tokenExchangeFailed(let msg): return "Token exchange failed: \(msg)"
        case .profileDecodeFailed: return "Could not decode Google profile"
        }
    }
}

@MainActor
final class GoogleAuthManager: NSObject {
    static let shared = GoogleAuthManager()

    private var session: ASWebAuthenticationSession?

    func signIn(presentationAnchor: ASPresentationAnchor) async throws -> GoogleProfile {
        let verifier = Self.makeCodeVerifier()
        let challenge = Self.codeChallenge(for: verifier)
        let state = UUID().uuidString

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            .init(name: "client_id", value: AuthConfig.googleClientID),
            .init(name: "redirect_uri", value: AuthConfig.googleRedirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state)
        ]
        guard let authURL = components.url else { throw GoogleAuthError.invalidResponse }

        let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: AuthConfig.googleRedirectScheme
            ) { url, error in
                if let error {
                    if let asError = error as? ASWebAuthenticationSessionError, asError.code == .canceledLogin {
                        cont.resume(throwing: GoogleAuthError.cancelled)
                    } else {
                        cont.resume(throwing: error)
                    }
                    return
                }
                guard let url else {
                    cont.resume(throwing: GoogleAuthError.invalidResponse)
                    return
                }
                cont.resume(returning: url)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            session.start()
        }

        guard let comps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = comps.queryItems?.first(where: { $0.name == "code" })?.value,
              let returnedState = comps.queryItems?.first(where: { $0.name == "state" })?.value,
              returnedState == state else {
            throw GoogleAuthError.invalidResponse
        }

        return try await exchangeCode(code, verifier: verifier)
    }

    private func exchangeCode(_ code: String, verifier: String) async throws -> GoogleProfile {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": AuthConfig.googleClientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": AuthConfig.googleRedirectURI
        ]
        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "unknown"
            throw GoogleAuthError.tokenExchangeFailed(msg)
        }

        struct TokenResponse: Decodable {
            let access_token: String
            let id_token: String
            let refresh_token: String?
        }
        let tokens = try JSONDecoder().decode(TokenResponse.self, from: data)
        let claims = try Self.decodeIDToken(tokens.id_token)

        return GoogleProfile(
            sub: claims.sub,
            email: claims.email,
            name: claims.name,
            idToken: tokens.id_token,
            accessToken: tokens.access_token,
            refreshToken: tokens.refresh_token
        )
    }

    private struct IDTokenClaims: Decodable {
        let sub: String
        let email: String?
        let name: String?
    }

    private static func decodeIDToken(_ jwt: String) throws -> IDTokenClaims {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { throw GoogleAuthError.profileDecodeFailed }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }
        guard let data = Data(base64Encoded: payload) else { throw GoogleAuthError.profileDecodeFailed }
        return try JSONDecoder().decode(IDTokenClaims.self, from: data)
    }

    private static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64URLEncodedString()
    }
}

extension GoogleAuthManager: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            if let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first {
                return window
            }
            if let scene {
                return ASPresentationAnchor(windowScene: scene)
            }
            return ASPresentationAnchor()
        }
    }
}

// Base64URL helpers live in `Networking/Base64URL.swift` (shared with PasskeyAPIClient).
