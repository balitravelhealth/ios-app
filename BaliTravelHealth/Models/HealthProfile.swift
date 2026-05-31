import Foundation

enum JenisKelamin: String, Codable, CaseIterable, Identifiable, Sendable {
    case lakiLaki = "L"
    case perempuan = "P"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .lakiLaki: return "Laki-laki"
        case .perempuan: return "Perempuan"
        }
    }
}

enum GolonganDarah: String, Codable, CaseIterable, Identifiable, Sendable {
    case a = "A"
    case b = "B"
    case ab = "AB"
    case o = "O"

    var id: String { rawValue }
}

struct HealthProfile: Codable, Equatable, Sendable {
    let id: Int?
    let userId: Int?
    var tanggalLahir: String?
    var jenisKelamin: JenisKelamin?
    var tinggiCm: Double?
    var beratKg: Double?
    var golonganDarah: GolonganDarah?
    var riwayatAlergi: String?
    let createdAt: String?
    let updatedAt: String?
}

struct HealthProfileRequest: Encodable, Sendable {
    var tanggalLahir: String?
    var jenisKelamin: JenisKelamin?
    var tinggiCm: Double?
    var beratKg: Double?
    var golonganDarah: GolonganDarah?
    var riwayatAlergi: String?
}
