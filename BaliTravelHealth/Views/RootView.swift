import SwiftUI

struct RootView: View {
    @Environment(AuthenticationManager.self) private var auth
    @Environment(ProfileStore.self) private var profileStore

    // Owned here (View initializer runs on main actor) and propagated
    // down the tree via @Environment so PreTravelView, PostTravelView,
    // NursingCareView, and RootView itself can all read them.
    @State private var coordinator = AppLaunchCoordinator.shared
    @State private var network = NetworkMonitor.shared

    @State private var profileResumedFor: String?

    var body: some View {
        ZStack {
            authContent
        }
        .animation(.easeInOut(duration: 0.4), value: coordinator.state == .fetching)
        .environment(coordinator)
        .environment(network)
        .onChange(of: auth.status) { _, newStatus in
            if case .signedOut = newStatus {
                profileResumedFor = nil
            }
        }
    }

    // MARK: - Auth-driven content

    @ViewBuilder
    private var authContent: some View {
        switch auth.status {
        case .unknown:
            systemLoadingView
        case .signedOut:
            LoginView()
        case .signedIn(let user):
            contentForSignedIn(user)
        }
    }

    @ViewBuilder
    private func contentForSignedIn(_ user: AuthenticatedUser) -> some View {
        // While the very first profile fetch is in flight, show a loader
        // instead of flashing the OnboardingFlow at returning users.
        if profileResumedFor != user.id
            && !profileStore.didCompleteOnboarding
            && !AppFlags.useDummyData {
            systemLoadingView
        } else if profileStore.didCompleteOnboarding {
            ZStack {
                MainTabView()
                // Splash overlay while pre-fetching initial data
                if coordinator.state == .fetching {
                    LaunchLoadingView(statusMessage: coordinator.statusMessage)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task(id: user.id) {
                // Kick off the launch data-fetch once per sign-in session
                await coordinator.performLaunch()
            }
        } else {
            OnboardingFlow()
        }
    }

    private var signedInUserID: String? {
        if case let .signedIn(user) = auth.status { return user.id }
        return nil
    }

    private var systemLoadingView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ProgressView().tint(.white)
        }
        .task(id: signedInUserID) {
            guard let uid = signedInUserID,
                  profileResumedFor != uid,
                  !AppFlags.useDummyData else { return }
            await profileStore.refreshFromServer()
            profileResumedFor = uid
        }
    }
}
