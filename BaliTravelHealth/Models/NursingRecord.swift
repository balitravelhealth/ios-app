import Foundation

struct NursingRecord: Codable, Identifiable, Sendable {
    let id: Int
    let nurseId: Int?
    let tanggalKunjungan: String     // "YYYY-MM-DD"
    let nursingAssessment: String?
    let nursingDiagnosis: String?
    let nursingPlanning: String?
    let nursingImplementation: String?
    let nursingEvaluation: String?
    let createdAt: String?
    let updatedAt: String?
}

struct NursingAppointmentRequest: Encodable, Sendable {
    let nurseId: Int
    let tanggalKunjungan: Date
}
