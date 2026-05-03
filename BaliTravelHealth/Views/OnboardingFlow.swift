import SwiftUI

/// Wraps the multi-step onboarding (profile → travel) in a NavigationStack.
struct OnboardingFlow: View {
    @State private var path: [OnboardingStep] = []

    enum OnboardingStep: Hashable {
        case travel
    }

    var body: some View {
        NavigationStack(path: $path) {
            SetupView(onContinue: { path.append(.travel) })
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .travel:
                        SetupTravelView()
                    }
                }
        }
    }
}
