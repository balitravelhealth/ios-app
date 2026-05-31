import Foundation
import CoreLocation

/// Booking payload sent to the server when the user taps **Book**.
///
/// Server JSON shape (matches `CodingKeys`):
/// ```json
/// {
///   "nurseId": "n_001",
///   "scheduledAt": "2026-06-14T09:00:00Z",
///   "address": "Jl. Sunset Road No. 818, Kuta",
///   "latitude": -8.71,
///   "longitude": 115.17,
///   "description": "Outpatient follow-up after dengue."
/// }
/// ```
struct AppointmentRequest: Codable, Sendable {
    let nurseId: String
    let scheduledAt: Date
    let address: String
    let latitude: Double
    let longitude: Double
    let description: String

    enum CodingKeys: String, CodingKey {
        case nurseId, scheduledAt, address, latitude, longitude, description
    }
}

/// Result returned by the server on a successful booking.
struct AppointmentConfirmation: Decodable, Sendable {
    let appointmentId: String
}

/// User-facing booking errors. Reads cleanly in alerts; never exposes
/// technical jargon.
enum AppointmentError: LocalizedError {
    case noInternet
    case timeout
    case serverUnreachable
    case server(Int)
    case unknown

    var errorDescription: String? {
        switch self {
        case .noInternet:
            return "You're offline. Check your Wi-Fi or cellular connection and try again."
        case .timeout:
            return "The booking request timed out. Please try again."
        case .serverUnreachable:
            return "We couldn't reach Bali Travel Health right now. Please try again in a moment."
        case .server:
            return "Your booking couldn't be completed. Please try again."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }

    init(from error: Error) {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                self = .noInternet
            case .timedOut:
                self = .timeout
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                self = .serverUnreachable
            default:
                self = .unknown
            }
        } else {
            self = .unknown
        }
    }
}
