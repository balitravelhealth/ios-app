import Foundation

@MainActor
@Observable
final class VaccinationService {
    static let shared = VaccinationService()

    private(set) var vaccinations: [Vaccination] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    func fetch() async {
        if AppFlags.useDummyData { return }
        isLoading = true
        defer { isLoading = false }
        lastError = nil
        do {
            let req = BaliAPI.authedRequest("vaccinations")
            let (data, status) = try await BaliAPI.perform(req)
            guard (200..<300).contains(status) else {
                throw BaliAPIError.from(data: data, status: status)
            }
            vaccinations = try BaliAPI.decodeArray(Vaccination.self, from: data)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func add(_ payload: VaccinationRequest) async throws {
        var req = BaliAPI.authedRequest("vaccinations", method: "POST")
        req.httpBody = try BaliAPI.encoder.encode(payload)
        let created = try await BaliAPI.perform(req, as: Vaccination.self)
        vaccinations.append(created)
    }

    func delete(id: Int) async throws {
        let req = BaliAPI.authedRequest("vaccinations/\(id)", method: "DELETE")
        let (data, status) = try await BaliAPI.perform(req)
        if status == 404 { throw BaliAPIError.notFound }
        guard (200..<300).contains(status) else {
            throw BaliAPIError.from(data: data, status: status)
        }
        vaccinations.removeAll { $0.id == id }
    }
}
