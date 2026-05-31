import Foundation

@MainActor
@Observable
final class DestinationService {
    static let shared = DestinationService()

    private(set) var destinations: [Destination] = []
    private(set) var healthRisks: [Int: [HealthRisk]] = [:]
    private(set) var isLoading = false
    private(set) var lastError: String?

    func fetchDestinations() async {
        isLoading = true
        defer { isLoading = false }
        lastError = nil
        do {
            let req = BaliAPI.request("destinations")
            destinations = try await BaliAPI.performArray(req, of: Destination.self)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func fetchHealthRisks(destinationId: Int) async throws -> [HealthRisk] {
        let req = BaliAPI.request("destinations/\(destinationId)/health-risks")
        let risks = try await BaliAPI.performArray(req, of: HealthRisk.self)
        healthRisks[destinationId] = risks
        return risks
    }
}
