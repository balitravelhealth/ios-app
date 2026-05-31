import Foundation

struct Destination: Codable, Identifiable, Sendable {
    let id: Int
    let namaDaerah: String
    let createdAt: String?
}

struct HealthRisk: Codable, Identifiable, Sendable {
    let id: Int
    let destinationId: Int
    let namaRisiko: String
    let saranPencegahan: String
    let rekomendasiVaksinasi: String?
    let createdAt: String?
    let updatedAt: String?
}
