import Foundation

@MainActor
@Observable
final class ExpertSymptomService {
    static let shared = ExpertSymptomService()

    private(set) var symptoms: [ExpertSymptom] = []
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var isUnavailable = false

    func fetch(kategori: AssessmentKategori) async {
        // 1. Serve from cache immediately for instant UI
        if let cached = try? await LocalDataCache.shared.loadSymptoms(for: kategori),
           !cached.isEmpty {
            symptoms = cached
        }

        // 2. If offline, stop here — show whatever cache has
        guard NetworkMonitor.shared.isConnected else {
            if symptoms.isEmpty { isUnavailable = true }
            return
        }

        // 3. Fetch fresh from network
        isLoading = true
        isUnavailable = false
        defer { isLoading = false }
        lastError = nil

        do {
            let fresh = try await AssessmentService.shared.fetchSymptoms(kategori: kategori)
            symptoms = fresh
            try? await LocalDataCache.shared.saveSymptoms(fresh, for: kategori)
        } catch BaliAPIError.notFound {
            isUnavailable = true
            if symptoms.isEmpty { symptoms = [] }
        } catch BaliAPIError.server(_, let msg) where msg.contains("not found") || msg.contains("404") {
            isUnavailable = true
            if symptoms.isEmpty { symptoms = [] }
        } catch {
            lastError = error.localizedDescription
            if symptoms.isEmpty { symptoms = [] }
        }
    }

    func reset() {
        symptoms = []
        lastError = nil
        isUnavailable = false
    }
}
