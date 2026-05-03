import Foundation

/// Which leg of the trip the advice is for.
enum TravelPhase: String, Sendable {
    case preTravel
    case postTravel
}

/// Supplies personalised travel-health advice for the current user.
///
/// This is a placeholder service — wire it to your backend / rules engine
/// later by replacing the body of `fetchAdvice(phase:profile:travel:)`. The
/// view layer already handles loading + empty + populated states.
@MainActor
@Observable
final class AdviceProvider {
    private(set) var advices: [Advice] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    /// Refresh the advice list for the given user context + travel phase.
    func refresh(phase: TravelPhase, profile: UserProfile?, travel: TravelInfo?) async {
        isLoading = true
        defer { isLoading = false }
        lastError = nil

        do {
            advices = try await fetchAdvice(phase: phase, for: profile, travel: travel)
        } catch {
            lastError = error.localizedDescription
            advices = []
        }
    }

    // MARK: - Pluggable fetch

    /// Replace this stub with a real network / local rules call.
    /// Throw to surface an error to the user, return `[]` for the empty state.
    private func fetchAdvice(phase: TravelPhase,
                             for profile: UserProfile?,
                             travel: TravelInfo?) async throws -> [Advice] {
        // TODO: integrate real advice source (server endpoint or local rules engine).
        // Branch on `phase` to return pre- or post-travel guidance.
        //
        // Example seed data — uncomment to preview the populated state:
        //
        // switch phase {
        // case .preTravel:
        //     return [Advice(title: "Get a typhoid shot",
        //                    body: "Recommended at least 2 weeks before arrival.",
        //                    symbolName: "syringe.fill",
        //                    severity: .warning)]
        // case .postTravel:
        //     return [Advice(title: "Watch for fever in the next 14 days",
        //                    body: "If you feel feverish, get a malaria/dengue test.",
        //                    symbolName: "thermometer.high",
        //                    severity: .warning)]
        // }

        return []
    }
}
