import Foundation
import AuthenticationServices
import UIKit

struct AuthenticatedUser: Sendable, Equatable {
    let id: String
    let name: String?
    let email: String?
    let provider: AuthProvider
}

enum AuthenticationError: Error, LocalizedError {
    case invalidCredential
    case cancelled
    /// Server returned 401 / 403 — the user cannot proceed past the login screen.
    case unauthorized
    case server(String)
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCredential: return "Invalid credentials"
        case .cancelled: return nil
        case .unauthorized:
            return "We couldn't verify your sign-in. Please try again."
        case .server(let msg): return msg
        case .underlying(let err): return err.localizedDescription
        }
    }
}

@MainActor
@Observable
final class AuthenticationManager {
    enum Status: Equatable {
        case unknown
        case signedOut
        case signedIn(AuthenticatedUser)
    }

    private(set) var status: Status = .unknown
    private(set) var isLoading = false
    var error: AuthenticationError?

    var isAuthenticated: Bool {
        if case .signedIn = status { return true }
        return false
    }

    init() {
        Task { await restoreSession() }
    }

    // MARK: - Restore on launch

    func restoreSession() async {
        let kc = KeychainManager.shared
        guard let userID = kc.get(.userID),
              let providerRaw = kc.get(.provider),
              let provider = AuthProvider(rawValue: providerRaw),
              let token = kc.get(.sessionToken) else {
            status = .signedOut
            return
        }

        // Drop a leftover dummy-mode session if the app has since been
        // flipped to real-server mode. The dummy token would just trigger
        // 401s on every protected route.
        if !AppFlags.useDummyData && token == "dummy.session.token" {
            signOut()
            return
        }

        // Optimistic restore: trust the locally-stored token immediately so the
        // user lands on Home right away, even when offline.
        status = .signedIn(AuthenticatedUser(
            id: userID,
            name: kc.get(.userName),
            email: kc.get(.userEmail),
            provider: provider
        ))

        // Only force a sign-out on a *definitive* server rejection. Apple's
        // credential state is checked the same way: only `.revoked` is a
        // definitive "this user is no longer authorised". Everything else
        // (notFound on a fresh simulator, transferred, network errors, 404,
        // 405, 5xx…) is ambiguous and must NOT clear the user's session.

        if provider == .apple {
            let state = await SignInWithAppleManager.shared.checkCredentialState(userID: userID)
            if state == .revoked {
                signOut()
                return
            }
        }

        let validity = await AuthAPIClient.shared.validate(sessionToken: token)
        if validity == .invalid {
            signOut()
            return
        }
        // .valid or .unknown → stay signed in.
    }

    // MARK: - Sign in with Apple

    /// Skip OAuth entirely and create a local test user. Wired to the
    /// "Continue as Test User" button on the login screen when
    /// `AppFlags.useDummyData == true`.
    func signInAsTestUser() async {
        isLoading = true
        defer { isLoading = false }
        await completeSignIn(
            provider: .apple,
            providerUserID: "test_user_001",
            identityToken: "dummy.identity.token",
            email: "test@balitravelhealth.app",
            name: "Test Traveler"
        )
    }

    // MARK: - Passkey

    /// Sign in (or register) via the system Passkey UI.
    /// Single tap → iOS shows the right affordance based on whether the device
    /// already has a passkey for this RP. The server returns a session on
    /// success; any 401 from the server is treated as a hard failure and the
    /// user is **not** signed in.
    func signInWithPasskey() async {
        if AppFlags.useDummyData {
            await signInAsTestUser()
            return
        }

        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            let begin = try await PasskeyAPIClient.shared.begin()

            guard let regChallenge = Data(base64URLEncoded: begin.registrationChallenge),
                  let regUserID    = Data(base64URLEncoded: begin.registrationUserId),
                  let logChallenge = Data(base64URLEncoded: begin.loginChallenge) else {
                error = .invalidCredential
                return
            }

            let result = try await PasskeyManager.shared.authenticate(
                rpId: begin.rpId,
                registrationChallenge: regChallenge,
                registrationUserID: regUserID,
                registrationDisplayName: begin.registrationDisplayName,
                loginChallenge: logChallenge
            )

            let session: ServerSession
            switch result {
            case .registration(let reg):
                guard let attestation = reg.rawAttestationObject else {
                    error = .invalidCredential
                    return
                }
                session = try await PasskeyAPIClient.shared.finishRegistration(
                    credentialID: reg.credentialID,
                    attestationObject: attestation,
                    clientDataJSON: reg.rawClientDataJSON
                )

            case .assertion(let assert):
                session = try await PasskeyAPIClient.shared.finishAssertion(
                    credentialID: assert.credentialID,
                    authenticatorData: assert.rawAuthenticatorData,
                    clientDataJSON: assert.rawClientDataJSON,
                    signature: assert.signature,
                    userHandle: assert.userID
                )
            }

            persist(session: session, provider: .passkey)
            status = .signedIn(AuthenticatedUser(
                id: session.userID,
                name: session.name,
                email: session.email,
                provider: .passkey
            ))

        } catch let asError as ASAuthorizationError where asError.code == .canceled {
            // User dismissed the system sheet — silent.
            error = nil
        } catch AuthAPIError.server(let status, _) where status == 401 || status == 403 {
            error = .unauthorized
        } catch let apiError as AuthAPIError {
            error = .server(apiError.errorDescription ?? "Server error.")
        } catch {
            self.error = .underlying(error)
        }
    }

    // MARK: - Google

    func signInWithGoogle() async {
        if AppFlags.useDummyData {
            await signInAsTestUser()
            return
        }

        isLoading = true
        defer { isLoading = false }

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first else {
            error = .invalidCredential
            return
        }

        do {
            let profile = try await GoogleAuthManager.shared.signIn(presentationAnchor: window)
            await completeSignIn(
                provider: .google,
                providerUserID: profile.sub,
                identityToken: profile.idToken,
                email: profile.email,
                name: profile.name
            )
        } catch GoogleAuthError.cancelled {
            error = nil
        } catch {
            self.error = .underlying(error)
        }
    }

    // MARK: - Sign out

    func signOut() {
        KeychainManager.shared.clearAll()
        status = .signedOut
    }

    // MARK: - Private

    private func completeSignIn(provider: AuthProvider,
                                providerUserID: String,
                                identityToken: String,
                                email: String?,
                                name: String?) async {
        if AppFlags.useDummyData {
            // Persist local-only test session.
            let kc = KeychainManager.shared
            kc.save(providerUserID, for: .userID)
            kc.save(provider.rawValue, for: .provider)
            kc.save("dummy.session.token", for: .sessionToken)
            if let name { kc.save(name, for: .userName) }
            if let email { kc.save(email, for: .userEmail) }
            status = .signedIn(AuthenticatedUser(
                id: providerUserID,
                name: name,
                email: email,
                provider: provider
            ))
            error = nil
            return
        }

        do {
            let session = try await AuthAPIClient.shared.signInOrSignUp(
                provider: provider,
                providerUserID: providerUserID,
                identityToken: identityToken,
                email: email,
                name: name
            )
            persist(session: session, provider: provider)
            status = .signedIn(AuthenticatedUser(
                id: session.userID,
                name: session.name ?? name,
                email: session.email ?? email,
                provider: provider
            ))
            error = nil
        } catch AuthAPIError.server(let status, _) where status == 401 || status == 403 {
            // Hard fail — user must NOT progress past the login screen.
            self.error = .unauthorized
        } catch let apiError as AuthAPIError {
            self.error = .server(apiError.errorDescription ?? "Server error.")
        } catch {
            self.error = .underlying(error)
        }
    }

    private func persist(session: ServerSession, provider: AuthProvider) {
        let kc = KeychainManager.shared
        kc.save(session.userID, for: .userID)
        kc.save(provider.rawValue, for: .provider)
        kc.save(session.sessionToken, for: .sessionToken)
        if let refresh = session.refreshToken { kc.save(refresh, for: .refreshToken) }
        if let name = session.name { kc.save(name, for: .userName) }
        if let email = session.email { kc.save(email, for: .userEmail) }
    }
}
