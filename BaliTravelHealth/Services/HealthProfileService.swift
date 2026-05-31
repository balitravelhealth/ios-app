import Foundation

@MainActor
@Observable
final class HealthProfileService {
    static let shared = HealthProfileService()

    private(set) var profile: HealthProfile?
    private(set) var isLoading = false
    private(set) var lastError: String?

    func fetch() async {
        if AppFlags.useDummyData { return }
        isLoading = true
        defer { isLoading = false }
        lastError = nil
        do {
            let req = BaliAPI.authedRequest("health-profile")
            let (data, status) = try await BaliAPI.perform(req)
            if status == 404 { profile = nil; return }
            guard (200..<300).contains(status) else {
                throw BaliAPIError.from(data: data, status: status)
            }
            profile = try BaliAPI.decode(HealthProfile.self, from: data)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func create(_ payload: HealthProfileRequest) async throws -> HealthProfile {
        var req = BaliAPI.authedRequest("health-profile", method: "POST")
        req.httpBody = try BaliAPI.encoder.encode(payload)
        let created = try await BaliAPI.perform(req, as: HealthProfile.self)
        profile = created
        return created
    }

    func update(_ payload: HealthProfileRequest) async throws -> HealthProfile {
        var req = BaliAPI.authedRequest("health-profile", method: "PUT")
        req.httpBody = try BaliAPI.encoder.encode(payload)
        let updated = try await BaliAPI.perform(req, as: HealthProfile.self)
        profile = updated
        return updated
    }

    /// Creates or updates depending on whether a profile is already on file.
    func save(_ payload: HealthProfileRequest) async throws {
        do {
            if profile == nil {
                _ = try await create(payload)
            } else {
                _ = try await update(payload)
            }
        } catch BaliAPIError.conflict {
            _ = try await update(payload)
        }
    }
}
