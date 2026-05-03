import SwiftUI

struct RootView: View {
    @Environment(AuthenticationManager.self) private var auth
    @Environment(ProfileStore.self) private var profileStore
    @State private var profileResumedFor: String?

    var body: some View {
        Group {
            switch auth.status {
            case .unknown:
                loadingView
            case .signedOut:
                LoginView()
            case .signedIn(let user):
                contentForSignedIn(user)
            }
        }
        // Pull the saved profile from the server every time we see a new
        // signed-in user. If the server has them on file we route straight
        // to Home; otherwise the user goes through onboarding once.
        .task(id: signedInUserID) {
            guard let uid = signedInUserID,
                  profileResumedFor != uid,
                  !AppFlags.useDummyData else { return }
            await profileStore.refreshFromServer()
            profileResumedFor = uid
        }
    }

    @ViewBuilder
    private func contentForSignedIn(_ user: AuthenticatedUser) -> some View {
        // While the very first profile fetch is in flight, show a loader
        // instead of flashing the OnboardingFlow at returning users.
        if profileResumedFor != user.id
            && !profileStore.didCompleteOnboarding
            && !AppFlags.useDummyData {
            loadingView
        } else if profileStore.didCompleteOnboarding {
            MainTabView()
        } else {
            OnboardingFlow()
        }
    }

    private var signedInUserID: String? {
        if case let .signedIn(user) = auth.status { return user.id }
        return nil
    }

    private var loadingView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ProgressView().tint(.white)
        }
    }
}
