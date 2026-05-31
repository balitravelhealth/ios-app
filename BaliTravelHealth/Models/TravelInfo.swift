import Foundation

enum BaliSeason: String, Codable, Sendable {
    case rainy
    case dry

    /// MP4 filename (without extension) shipped in the app bundle.
    var videoResourceName: String {
        switch self {
        case .rainy: return "rain"
        case .dry:   return "palm"
        }
    }

    /// Bali rainy season runs roughly November through March.
    static func season(for date: Date, calendar: Calendar = .current) -> BaliSeason {
        let month = calendar.component(.month, from: date)
        return [11, 12, 1, 2, 3].contains(month) ? .rainy : .dry
    }
}

struct TravelInfo: Codable, Equatable, Sendable {
    var arrivalDate: Date
    var departureDate: Date

    var nights: Int {
        let components = Calendar.current.dateComponents([.day], from: arrivalDate, to: departureDate)
        return max(0, components.day ?? 0)
    }

    var season: BaliSeason {
        BaliSeason.season(for: arrivalDate)
    }
}
