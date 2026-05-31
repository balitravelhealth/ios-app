import Foundation

@MainActor
@Observable
final class EmergencyGuideAPIService {
    static let shared = EmergencyGuideAPIService()

    private(set) var steps: [EmergencyGuideStep] = []
    private(set) var flows: [EmergencyGuideFlowSummary] = []
    // Separate counters to handle concurrent fetchFlows + fetchSteps correctly
    private var loadingCount = 0 {
        didSet { isLoading = loadingCount > 0 }
    }
    private(set) var isLoading = false
    private(set) var lastError: String?

    // MARK: - Cache injection (called by AppLaunchCoordinator)

    func setSteps(_ newSteps: [EmergencyGuideStep]) {
        steps = newSteps
    }

    func setFlows(_ newFlows: [EmergencyGuideFlowSummary]) {
        flows = newFlows
    }

    // MARK: - Fetches (load cache first, then network)

    /// Fetches sequential step guides. Pass a kategori (e.g. "bls", "tersedak") to filter.
    func fetchSteps(kategori: String? = nil) async {
        // Seed from cache immediately if data is not yet loaded
        if steps.isEmpty, let cached = try? await LocalDataCache.shared.loadSteps() {
            steps = cached
        }
        guard NetworkMonitor.shared.isConnected else { return }

        loadingCount += 1
        defer { loadingCount -= 1 }
        lastError = nil
        do {
            let query = kategori.map { [URLQueryItem(name: "kategori", value: $0)] } ?? []
            let req = BaliAPI.request("emergency-guides", queryItems: query)
            let fetched = try await BaliAPI.performArray(req, of: EmergencyGuideStep.self)
            steps = fetched
            try? await LocalDataCache.shared.saveSteps(fetched)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Fetches all decision-tree flow summaries.
    func fetchFlows() async {
        // Seed from cache immediately if data is not yet loaded
        if flows.isEmpty, let cached = try? await LocalDataCache.shared.loadFlows() {
            flows = cached
        }
        guard NetworkMonitor.shared.isConnected else { return }

        loadingCount += 1
        defer { loadingCount -= 1 }
        lastError = nil
        do {
            let req = BaliAPI.request("emergency-guide-flows")
            let fetched = try await BaliAPI.performArray(req, of: EmergencyGuideFlowSummary.self)
            flows = fetched
            try? await LocalDataCache.shared.saveFlows(fetched)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Fetches a single flow with all its nodes and choices.
    /// Tries the local cache first; falls back to network when online.
    func fetchFlowDetail(id: Int) async throws -> EmergencyGuideFlowDetail {
        // Try cache first
        if let cached = try? await LocalDataCache.shared.loadFlowDetail(id: id) {
            // Refresh in background if online
            if NetworkMonitor.shared.isConnected {
                Task {
                    let req = BaliAPI.request("emergency-guide-flows/\(id)")
                    if let fresh = try? await BaliAPI.perform(req, as: EmergencyGuideFlowDetail.self) {
                        try? await LocalDataCache.shared.saveFlowDetail(fresh)
                    }
                }
            }
            return cached
        }

        // Nothing cached — must go to network
        guard NetworkMonitor.shared.isConnected else {
            throw BaliAPIError.unavailable
        }
        let req = BaliAPI.request("emergency-guide-flows/\(id)")
        let detail = try await BaliAPI.perform(req, as: EmergencyGuideFlowDetail.self)
        try? await LocalDataCache.shared.saveFlowDetail(detail)
        return detail
    }
}
