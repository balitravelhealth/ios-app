import Foundation

struct TravelerProfile: Codable, Equatable, Sendable {
    let id: Int?
    let userId: Int?
    var namaLengkap: String
    var tanggalLahir: String?    // "YYYY-MM-DD"
    var kontakDarurat: String?
    let createdAt: String?
    let updatedAt: String?
}

struct TravelerProfileRequest: Encodable, Sendable {
    var namaLengkap: String
    var tanggalLahir: String
    var kontakDarurat: String
}
