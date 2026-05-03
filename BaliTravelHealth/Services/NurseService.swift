import Foundation

/// Fetches nurses available through the Nursing Care service.
///
/// **Backend wiring** — replace `endpoint` and the body of `fetchAll()` with
/// your real route. Expected JSON shape (snake_case is fine — adjust the
/// decoder's `keyDecodingStrategy` if needed):
///
/// ```json
/// [
///   {
///     "id": "n_001",
///     "name": "Made Suparna",
///     "experience": "8 years experience",
///     "base_rate": 250000,
///     "currency_code": "IDR",
///     "avatar_url": "https://cdn.example.com/n_001.jpg",
///     "bio": "Specialised in elderly home care."
///   }
/// ]
/// ```
@MainActor
@Observable
final class NurseService {
    static let shared = NurseService()

    /// Replace with your real endpoint, e.g. `https://balihealth.me/nurses.php`
    var endpoint: URL = URL(string: "https://balihealth.me/internal/nurses.php")!

    private(set) var nurses: [Nurse] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    /// Re-fetch the list. Sets `nurses`, `isLoading`, and `lastError`.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        lastError = nil
        do {
            nurses = try await fetchAll()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Pluggable network call. Authenticates with the stored session token if
    /// one is present in Keychain — strip the header if your endpoint is open.
    private func fetchAll() async throws -> [Nurse] {
        if AppFlags.useDummyData {
            try? await Task.sleep(nanoseconds: 250_000_000)   // small delay to feel real
            return DummyData.nurses
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.applyAppUserAgent()
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = KeychainManager.shared.get(.sessionToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([Nurse].self, from: data)
    }
}
