import Foundation

enum Gender: String, Codable, CaseIterable, Identifiable, Sendable {
    case male
    case female

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        }
    }
}

struct UserProfile: Codable, Equatable, Sendable {
    var name: String
    var countryCode: String          // ISO 3166-1 alpha-2 (e.g. "ID", "US")
    var dateOfBirth: Date
    var gender: Gender
    var emergencyContact: String?

    var localizedCountryName: String {
        Locale.current.localizedString(forRegionCode: countryCode) ?? countryCode
    }
}
