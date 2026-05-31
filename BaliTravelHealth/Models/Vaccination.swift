import Foundation

struct Vaccination: Codable, Identifiable, Sendable {
    let id: Int
    let userId: Int?
    var jenisVaksin: String
    var tanggal: String     // "YYYY-MM-DD"
    var dosis: String?
    var catatan: String?
    let createdAt: String?
}

struct VaccinationRequest: Encodable, Sendable {
    var jenisVaksin: String
    var tanggal: String
    var dosis: String?
    var catatan: String?
}
