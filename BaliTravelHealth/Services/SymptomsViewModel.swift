import Foundation

@MainActor
@Observable
final class SymptomsViewModel {
    private let service: AssessmentService

    private(set) var symptoms: [Symptom] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var selectedSymptomIDs = Set<Int>()

    // Default-parameter expressions are nonisolated in Swift 6, so we can't
    // write `= .shared` there. Provide two explicit inits instead.
    init() {
        self.service = AssessmentService.shared
    }

    init(service: AssessmentService) {
        self.service = service
    }

    func load(kategori: AssessmentKategori) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            symptoms = try await service.fetchSymptoms(kategori: kategori)
        } catch {
            symptoms = []
            errorMessage = error.localizedDescription
        }
    }

    func toggle(_ symptom: Symptom) {
        if selectedSymptomIDs.contains(symptom.symptomID) {
            selectedSymptomIDs.remove(symptom.symptomID)
        } else {
            selectedSymptomIDs.insert(symptom.symptomID)
        }
    }

    func submit(kategori: AssessmentKategori) async -> AssessmentResult? {
        errorMessage = nil

        do {
            return try await service.submitAssessment(
                symptomIDs: Array(selectedSymptomIDs),
                kategori: kategori
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
