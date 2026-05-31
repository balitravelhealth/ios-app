import Foundation

// Sequential step-by-step guide (GET /emergency-guides)
struct EmergencyGuideStep: Codable, Identifiable, Sendable {
    let id: Int
    let kategori: String
    let langkah: Int
    let isiMedia: IsiMedia?
    let createdAt: String?
    let updatedAt: String?

    struct IsiMedia: Codable, Sendable {
        let judul: String?
        let teks: String?
        let ikon: String?
        let gambarUrl: String?
        // Emergency contact numbers
        let nomorDarurat: String?
        // Technique metrics
        let ritme: String?
        let kedalaman: String?
        let rasio: String?
        let jumlah: Int?
        // DARURAT category
        let nomor: String?
        let nomorPolisi: String?
        let nomorDamkar: String?
        let nomorUniversal: String?
    }
}

// Summary of a decision-tree flow (GET /emergency-guide-flows)
struct EmergencyGuideFlowSummary: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let kategori: String
    let deskripsi: String?
    let createdAt: String?
    let updatedAt: String?
}

// Full flow including all nodes (GET /emergency-guide-flows/:id)
struct EmergencyGuideFlowDetail: Codable, Identifiable, Sendable {
    let id: Int
    let title: String
    let kategori: String
    let deskripsi: String?
    let nodes: [GuideFlowNode]
    let createdAt: String?
    let updatedAt: String?
}

struct GuideFlowNode: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let instruction: String
    let imageUrl: String?
    let isEntry: Bool?
    let choices: [GuideFlowChoice]?
}

struct GuideFlowChoice: Codable, Sendable {
    let label: String
    let nextId: String?
    let variant: String     // "yes", "no", "neutral"
}
