import Foundation

/// One nurse offered through the Nursing Care service.
struct Nurse: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let name: String
    let experience: String      // e.g. "5 years experience"
    let baseRate: Decimal       // numeric rate (per hour or per visit) in IDR
    let currencyCode: String    // e.g. "IDR" / "USD"
    let avatarURL: URL?
    let bio: String?

    /// Localised "from {rate}" string for the card footer.
    func formattedFromRate() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 0
        let amount = formatter.string(from: baseRate as NSDecimalNumber) ?? "\(baseRate)"
        return "from \(amount)"
    }
}
