import Foundation
import SwiftUI

enum AssessmentKategori: String, Codable, Sendable {
    case preTravel = "pre_travel"
    case postTravel = "post_travel"

    var displayName: LocalizedStringKey {
        switch self {
        case .preTravel:  return "Pre-Travel"
        case .postTravel: return "Post-Travel"
        }
    }
}

enum RiskLevel: String, Codable, Sendable {
    case low
    case medium
    case high
    case emergency

    var displayName: LocalizedStringKey {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        case .emergency: return "Emergency"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self.normalized(rawValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static func normalized(_ value: String) -> RiskLevel {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        switch normalized {
        case "rendah", "low", "ringan":
            return .low
        case "sedang", "medium", "moderate":
            return .medium
        case "tinggi", "high", "severe":
            return .high
        case "darurat", "emergency", "critical", "urgent", "kritikal":
            return .emergency
        default:
            return .low
        }
    }
}

struct AssessmentResult: Codable, Identifiable, Sendable {
    let id: Int
    let userId: Int?
    let diagnosis: String
    let confidenceScore: Double
    let riskLevel: RiskLevel
    let recommendation: String
    let kategori: AssessmentKategori?
    let assessmentDate: String?
    let createdAt: String?

    init(
        id: Int,
        userId: Int?,
        diagnosis: String,
        confidenceScore: Double,
        riskLevel: RiskLevel,
        recommendation: String,
        kategori: AssessmentKategori?,
        assessmentDate: String?,
        createdAt: String?
    ) {
        self.id = id
        self.userId = userId
        self.diagnosis = diagnosis
        self.confidenceScore = confidenceScore
        self.riskLevel = riskLevel
        self.recommendation = recommendation
        self.kategori = kategori
        self.assessmentDate = assessmentDate
        self.createdAt = createdAt
    }

    // Nested wrapper the API returns on POST /assessment
    private struct DiagnosisResults: Decodable {
        let diagnosis: String?
        let confidenceScore: Double?
        let riskLevel: RiskLevel?
        let recommendation: String?
    }

    // Stored backend assessment rows keep the full expert response here.
    private struct ExpertAnalysis: Decodable {
        let diagnosis: String?
        let confidenceScore: Double?
        let riskLevel: RiskLevel?
        let recommendation: String?
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(Int.self, forKey: .id)
        userId          = try c.decodeIfPresent(Int.self, forKey: .userId)
        kategori        = try c.decodeIfPresent(AssessmentKategori.self, forKey: .kategori)
        assessmentDate  = try c.decodeIfPresent(String.self, forKey: .assessmentDate)
        createdAt       = try c.decodeIfPresent(String.self, forKey: .createdAt)

        if let nested = try c.decodeIfPresent(DiagnosisResults.self, forKey: .diagnosisResults) {
            diagnosis       = nested.diagnosis ?? ""
            confidenceScore = nested.confidenceScore ?? 0
            riskLevel       = nested.riskLevel ?? .low
            recommendation  = nested.recommendation ?? ""
        } else {
            let analysis = try c.decodeIfPresent(ExpertAnalysis.self, forKey: .aiAnalysisRaw)
            diagnosis       = try c.decodeIfPresent(String.self, forKey: .diagnosis) ?? analysis?.diagnosis ?? ""
            confidenceScore = try c.decodeIfPresent(Double.self, forKey: .confidenceScore) ?? analysis?.confidenceScore ?? 0
            riskLevel       = try c.decodeIfPresent(RiskLevel.self, forKey: .riskLevel) ?? analysis?.riskLevel ?? .low
            recommendation  = try c.decodeIfPresent(String.self, forKey: .recommendation) ?? analysis?.recommendation ?? ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(userId, forKey: .userId)
        try c.encode(diagnosis, forKey: .diagnosis)
        try c.encode(confidenceScore, forKey: .confidenceScore)
        try c.encode(riskLevel, forKey: .riskLevel)
        try c.encode(recommendation, forKey: .recommendation)
        try c.encodeIfPresent(kategori, forKey: .kategori)
        try c.encodeIfPresent(assessmentDate, forKey: .assessmentDate)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
    }

    enum CodingKeys: CodingKey {
        case id, userId, diagnosis, confidenceScore, riskLevel, recommendation
        case kategori, assessmentDate, createdAt, diagnosisResults, aiAnalysisRaw
    }

    func withKategori(_ fallbackKategori: AssessmentKategori?) -> AssessmentResult {
        AssessmentResult(
            id: id,
            userId: userId,
            diagnosis: diagnosis,
            confidenceScore: confidenceScore,
            riskLevel: riskLevel,
            recommendation: recommendation,
            kategori: kategori ?? fallbackKategori,
            assessmentDate: assessmentDate,
            createdAt: createdAt
        )
    }
}

struct AssessmentRequest: Encodable, Sendable {
    let symptoms: [Int]
    let kategori: String
}

struct Symptom: Codable, Identifiable, Hashable, Sendable {
    let symptomID: Int
    let kode: String
    let labelId: String
    let labelEn: String

    var id: Int { symptomID }

    var displayName: String {
        primaryDisplayName
    }

    var primaryDisplayName: String {
        Self.firstHumanReadable([labelEn, labelId]) ?? "Symptom \(symptomID)"
    }

    var secondaryDisplayName: String? {
        guard let label = Self.firstHumanReadable([labelId]),
              label != primaryDisplayName
        else {
            return nil
        }
        return label
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case symptomId
        case kode
        case labelId
        case labelEn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symptomID = try container.decodeIfPresent(Int.self, forKey: .symptomId)
            ?? container.decode(Int.self, forKey: .id)
        kode = try container.decodeIfPresent(String.self, forKey: .kode) ?? ""
        labelId = try container.decodeIfPresent(String.self, forKey: .labelId) ?? ""
        labelEn = try container.decodeIfPresent(String.self, forKey: .labelEn) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(symptomID, forKey: .symptomId)
        try container.encode(kode, forKey: .kode)
        try container.encode(labelId, forKey: .labelId)
        try container.encode(labelEn, forKey: .labelEn)
    }

    private static func firstHumanReadable(_ values: [String]) -> String? {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !isSymptomCode($0) }
    }

    private static func isSymptomCode(_ value: String) -> Bool {
        let pattern = #"^[A-Z]+_[A-Z0-9_]+$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}

typealias ExpertSymptom = Symptom
