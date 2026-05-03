import Foundation

/// Sends nursing-care appointment requests to the backend.
///
/// **Wire your endpoint here.** Replace `endpoint` with the real URL and adjust
/// the JSON shape on the server to match `AppointmentRequest`. The client
/// throws `AppointmentError` so the UI can show plain-language messages.
struct AppointmentAPIClient: Sendable {
    static let shared = AppointmentAPIClient()

    /// TODO: replace with your real appointments endpoint.
    /// Example: `https://balihealth.me/appointments.php`
    var endpoint: URL = URL(string: "https://balihealth.me/internal/appointments.php")!

    /// TODO: replace with your real "current/active appointment" endpoint.
    /// Should return a single `ActiveAppointment` JSON object, or 204/404 when
    /// the user has no upcoming booking.
    var activeEndpoint: URL = URL(string: "https://balihealth.me/appointments-active.php")!

    func submit(_ payload: AppointmentRequest) async throws -> AppointmentConfirmation {
        if AppFlags.useDummyData {
            try? await Task.sleep(nanoseconds: 700_000_000)
            return DummyData.recordAppointment(payload)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.applyAppUserAgent()
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = KeychainManager.shared.get(.sessionToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AppointmentError.unknown
            }
            guard (200..<300).contains(http.statusCode) else {
                throw AppointmentError.server(http.statusCode)
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AppointmentConfirmation.self, from: data)
        } catch let error as AppointmentError {
            throw error
        } catch {
            throw AppointmentError(from: error)
        }
    }

    /// Returns the user's currently-booked appointment, or `nil` if none.
    /// Treats HTTP 204 / 404 as "no active appointment". Other failures throw
    /// `AppointmentError`.
    func fetchActive() async throws -> ActiveAppointment? {
        if AppFlags.useDummyData {
            return DummyData.loadActiveAppointment()
        }

        var request = URLRequest(url: activeEndpoint)
        request.httpMethod = "GET"
        request.applyAppUserAgent()
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = KeychainManager.shared.get(.sessionToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AppointmentError.unknown
            }
            if http.statusCode == 204 || http.statusCode == 404 {
                return nil
            }
            guard (200..<300).contains(http.statusCode) else {
                throw AppointmentError.server(http.statusCode)
            }
            if data.isEmpty { return nil }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(ActiveAppointment.self, from: data)
        } catch let error as AppointmentError {
            throw error
        } catch {
            throw AppointmentError(from: error)
        }
    }
}
