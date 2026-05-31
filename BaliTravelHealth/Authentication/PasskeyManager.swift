import Foundation
import AuthenticationServices
import UIKit

/// Drives the system Passkey UI for both registration (create) and assertion
/// (sign-in) flows. The challenges and user identifiers come from the server;
/// this class only orchestrates the local `ASAuthorizationController`.
@MainActor
final class PasskeyManager: NSObject {
    static let shared = PasskeyManager()

    enum PasskeyError: Error, LocalizedError {
        case unexpectedCredentialType
        case noPresentationAnchor

        var errorDescription: String? {
            switch self {
            case .unexpectedCredentialType: return "Unexpected credential returned by the system."
            case .noPresentationAnchor:     return "No window is available to present the system sheet."
            }
        }
    }

    /// Result of a single controller invocation. The system decides which one
    /// happens based on whether a passkey already exists for the RP ID.
    enum Result {
        case registration(ASAuthorizationPlatformPublicKeyCredentialRegistration)
        case assertion(ASAuthorizationPlatformPublicKeyCredentialAssertion)
    }

    private var continuation: CheckedContinuation<Result, Error>?

    /// Run register-or-sign-in in a single system prompt. iOS picks the right
    /// affordance: "Create a passkey" if none exists for this RP, or
    /// "Sign in with your saved passkey" if one does.
    func authenticate(
        rpId: String,
        registrationChallenge: Data,
        registrationUserID: Data,
        registrationDisplayName: String,
        loginChallenge: Data
    ) async throws -> Result {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)

        let registration = provider.createCredentialRegistrationRequest(
            challenge: registrationChallenge,
            name: registrationDisplayName,
            userID: registrationUserID
        )

        let assertion = provider.createCredentialAssertionRequest(challenge: loginChallenge)

        let controller = ASAuthorizationController(authorizationRequests: [registration, assertion])
        controller.delegate = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            controller.performRequests()
        }
    }

    /// Sign-in only (assertion). Use when you know the user has a passkey.
    func signIn(rpId: String, challenge: Data) async throws -> ASAuthorizationPlatformPublicKeyCredentialAssertion {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let request = provider.createCredentialAssertionRequest(challenge: challenge)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        let result: Result = try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            controller.performRequests()
        }
        guard case .assertion(let a) = result else { throw PasskeyError.unexpectedCredentialType }
        return a
    }
}

// MARK: - Delegate

extension PasskeyManager: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let cont = continuation else { return }
            continuation = nil

            if let registration = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
                cont.resume(returning: .registration(registration))
                return
            }
            if let assertion = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
                cont.resume(returning: .assertion(assertion))
                return
            }
            cont.resume(throwing: PasskeyError.unexpectedCredentialType)
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            guard let cont = continuation else { return }
            continuation = nil
            cont.resume(throwing: error)
        }
    }
}

// MARK: - Presentation context

extension PasskeyManager: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            if let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first {
                return window
            }
            if let scene { return ASPresentationAnchor(windowScene: scene) }
            return ASPresentationAnchor()
        }
    }
}
