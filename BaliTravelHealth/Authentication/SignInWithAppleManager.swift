import Foundation
import AuthenticationServices

final class SignInWithAppleManager: Sendable {
    static let shared = SignInWithAppleManager()
    private init() {}

    func checkCredentialState(userID: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }
}
