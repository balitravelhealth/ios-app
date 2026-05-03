import Foundation

/// Pushes the on-boarding profile + travel info to the server.
/// Endpoint expects POST JSON; replace URL with your real `profile.php` route.
struct ProfileAPIClient: Sendable {
    static let shared = ProfileAPIClient()

    private let endpoint = URL(string: "https://balihealth.me/internal/profile.php")!

    /// Sync onboarding payload. Throws on non-2xx.
    func upload(profile: UserProfile,
                travel: TravelInfo?,
                sessionToken: String) async throws {
        if AppFlags.useDummyData { return }     // local-only mode: nothing to send

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.applyAppUserAgent()
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]

        var payload: [String: Any] = [
            "name": profile.name,
            "countryCode": profile.countryCode,
            "dateOfBirth": isoFormatter.string(from: profile.dateOfBirth),
            "gender": profile.gender.rawValue
        ]
        if let travel {
            payload["arrivalDate"] = isoFormatter.string(from: travel.arrivalDate)
            payload["departureDate"] = isoFormatter.string(from: travel.departureDate)
            payload["season"] = travel.season.rawValue
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Fetch (resume after sign-in)

    struct FetchedProfile: Decodable, Sendable {
        let name: String
        let countryCode: String
        let dateOfBirth: String          // YYYY-MM-DD
        let gender: String
        let travel: FetchedTravel?

        struct FetchedTravel: Decodable, Sendable {
            let arrivalDate: String
            let departureDate: String
            let season: String?
        }
    }

    /// Pulls the user's saved profile from the server. Returns `nil` when
    /// the server has nothing on file (HTTP 204) — the iOS client should
    /// then route the user through onboarding.
    func fetch(sessionToken: String) async throws -> FetchedProfile? {
        if AppFlags.useDummyData { return nil }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.applyAppUserAgent()
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode == 204 || data.isEmpty { return nil }
        guard (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(FetchedProfile.self, from: data)
    }
}
