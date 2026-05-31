import Foundation

@MainActor
@Observable
final class AssessmentService {
    static let shared = AssessmentService()
    private static let categoryStoreKey = "balihealth.assessment.categoryById.v1"

    private(set) var history: [AssessmentResult] = []
    private(set) var latestResult: AssessmentResult?
    private(set) var isLoading = false
    private(set) var lastError: String?

    func fetchSymptoms(kategori: AssessmentKategori) async throws -> [Symptom] {
        let req = BaliAPI.request("expert/symptoms", queryItems: [
            URLQueryItem(name: "kategori", value: kategori.rawValue)
        ])
        let envelope = try await BaliAPI.perform(req, as: DataEnvelope<[Symptom]>.self)
        return envelope.data
    }

    func submit(symptoms: [Int], kategori: AssessmentKategori) async throws -> AssessmentResult {
        isLoading = true
        defer { isLoading = false }
        lastError = nil

        var req = BaliAPI.authedRequest("assessment", method: "POST")
        req.httpBody = try BaliAPI.encoder.encode(AssessmentRequest(symptoms: symptoms, kategori: kategori.rawValue))

        let result = try await BaliAPI.perform(req, as: AssessmentResult.self)
        let categorized = result.withKategori(kategori)
        store(kategori: kategori, for: categorized.id)
        latestResult = categorized
        return categorized
    }

    func submitAssessment(
        selectedSymptoms: [Symptom],
        kategori: AssessmentKategori
    ) async throws -> AssessmentResult {
        try await submitAssessment(
            symptomIDs: selectedSymptoms.map(\.symptomID),
            kategori: kategori
        )
    }

    func submitAssessment(
        symptomIDs: [Int],
        kategori: AssessmentKategori
    ) async throws -> AssessmentResult {
        try await submit(symptoms: symptomIDs, kategori: kategori)
    }

    func submitAssessment(
        symptomIDs: [Int64],
        kategori: AssessmentKategori
    ) async throws -> AssessmentResult {
        try await submit(symptoms: symptomIDs.map(Int.init), kategori: kategori)
    }

    func fetchHistory(page: Int = 1, limit: Int = 10) async {
        if AppFlags.useDummyData { return }
        isLoading = true
        defer { isLoading = false }
        lastError = nil
        do {
            let req = BaliAPI.authedRequest("assessments", queryItems: [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ])
            let results = try await BaliAPI.performArray(req, of: AssessmentResult.self)
            history = results.map(applyingStoredKategori)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func applyingStoredKategori(to result: AssessmentResult) -> AssessmentResult {
        if let kategori = result.kategori {
            store(kategori: kategori, for: result.id)
            return result
        }
        return result.withKategori(storedKategori(for: result.id))
    }

    private func store(kategori: AssessmentKategori, for assessmentID: Int) {
        var values = UserDefaults.standard.dictionary(forKey: Self.categoryStoreKey) as? [String: String] ?? [:]
        values[String(assessmentID)] = kategori.rawValue
        UserDefaults.standard.set(values, forKey: Self.categoryStoreKey)
    }

    private func storedKategori(for assessmentID: Int) -> AssessmentKategori? {
        let values = UserDefaults.standard.dictionary(forKey: Self.categoryStoreKey) as? [String: String] ?? [:]
        guard let rawValue = values[String(assessmentID)] else {
            return nil
        }
        return AssessmentKategori(rawValue: rawValue)
    }
}
