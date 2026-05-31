import Foundation

/// The user's currently-booked appointment as returned by the server.
///
/// Server JSON shape (matches `CodingKeys`):
/// ```json
/// {
///   "id": "appt_42",
///   "nurseId": "n_001",
///   "nurseName": "Made Suparna",
///   "nurseAvatarUrl": "https://cdn.example.com/n_001.jpg",
///   "nurseWhatsapp": "+62 811 398 3030",
///   "address": "Jl. Sunset Road No. 818, Kuta",
///   "scheduledAt": "2026-06-14T09:00:00Z"
/// }
/// ```
struct ActiveAppointment: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let nurseId: String
    let nurseName: String
    let nurseAvatarURL: URL?
    let nurseWhatsApp: String
    let address: String
    let scheduledAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case nurseId
        case nurseName
        case nurseAvatarURL = "nurseAvatarUrl"
        case nurseWhatsApp = "nurseWhatsapp"
        case address
        case scheduledAt
    }

    /// How long after the scheduled time we keep showing the appointment card
    /// before reverting to the nurse list.
    static let visibilityGrace: TimeInterval = 24 * 60 * 60   // 1 day

    /// Card stays visible until `scheduledAt + visibilityGrace`. After that,
    /// the Nursing Care screen falls back to the nurse list.
    var isStillVisible: Bool {
        Date() < scheduledAt.addingTimeInterval(Self.visibilityGrace)
    }

    /// `https://wa.me/<digits>?text=...` deep-link that opens WhatsApp directly
    /// into a chat with the nurse, pre-filled with a polite greeting.
    var whatsAppURL: URL? {
        let digits = nurseWhatsApp.unicodeScalars.filter(CharacterSet.decimalDigits.contains)
        let cleaned = String(String.UnicodeScalarView(digits))
        guard !cleaned.isEmpty else { return nil }
        let greeting = "Hi \(nurseName), I have an appointment with you on Bali Travel Health."
        var components = URLComponents(string: "https://wa.me/\(cleaned)")
        components?.queryItems = [URLQueryItem(name: "text", value: greeting)]
        return components?.url
    }
}
