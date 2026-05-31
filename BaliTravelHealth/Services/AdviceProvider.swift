import Foundation
import Translation

/// Which leg of the trip the advice is for.
enum TravelPhase: String, Sendable {
    case preTravel
    case postTravel
}

/// Derives personalised travel-health advice from the user's latest assessment result.
///
/// Flow:
/// 1. `refresh()` is called by the view on appear and pull-to-refresh.
/// 2. Internally it fetches assessment history (if not already loaded), finds the
///    latest result matching the current travel phase, and converts it to `Advice` items.
/// 3. On iOS 26+ it also translates the diagnosis / recommendation text so
///    `TranslatingText` in the advice cards can do a synchronous lookup.
@MainActor
@Observable
final class AdviceProvider {
    private(set) var advices: [Advice] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    func refresh(phase: TravelPhase, profile: UserProfile?, travel: TravelInfo?) async {
        isLoading = true
        defer { isLoading = false }
        lastError = nil
        do {
            advices = try await fetchAdvice(phase: phase)
        } catch {
            lastError = error.localizedDescription
            advices = []
        }
    }

    // MARK: - Advice from latest assessment result

    private func fetchAdvice(phase: TravelPhase) async throws -> [Advice] {
        let service = AssessmentService.shared
        let kategori: AssessmentKategori = phase == .preTravel ? .preTravel : .postTravel

        // Always refresh history so we pick up results from previous sessions.
        // This is a background network call; latestResult handles the just-submitted case.
        await service.fetchHistory(page: 1, limit: 10)

        // Priority 1 — in-session submission (kategori always correctly set by submit()).
        let fromSession: AssessmentResult? = service.latestResult?.kategori == kategori
            ? service.latestResult : nil

        // Priority 2 — server history filtered to this phase.
        // Some older records may have kategori == nil (server omitted it);
        // those are excluded from the filter and will not pollute the wrong phase.
        let fromHistory: AssessmentResult? = service.history
            .first(where: { $0.kategori == kategori })

        // Use whichever is newer (higher ID = newer on this backend).
        // If only one is available, use that one.
        let result: AssessmentResult?
        switch (fromSession, fromHistory) {
        case let (s?, h?):
            result = s.id >= h.id ? s : h
        case let (s?, nil):
            result = s
        case let (nil, h?):
            result = h
        case (nil, nil):
            result = nil
        }

        guard let result else { return [] }

        // Translate dynamic content before building advice so TranslatingText can
        // do a synchronous cache hit when the cards are rendered.
        if #available(iOS 26.0, *) {
            await translateContent(from: result)
        }

        return build(from: result)
    }

    // MARK: - Build Advice from AssessmentResult

    private func build(from result: AssessmentResult) -> [Advice] {
        guard !result.recommendation.isEmpty || !result.diagnosis.isEmpty else { return [] }

        let severity: Advice.Severity
        let symbol: String
        switch result.riskLevel {
        case .low:
            severity = .info
            symbol = "checkmark.shield.fill"
        case .medium:
            severity = .warning
            symbol = "exclamationmark.triangle.fill"
        case .high:
            severity = .critical
            symbol = "exclamationmark.shield.fill"
        case .emergency:
            severity = .critical
            symbol = "cross.case.fill"
        }

        let title = result.diagnosis.isEmpty
            ? defaultTitle(for: result.riskLevel)
            : result.diagnosis

        let body = result.recommendation.isEmpty
            ? defaultBody(for: result.riskLevel)
            : result.recommendation

        return [Advice(title: title, body: body, symbolName: symbol, severity: severity)]
    }

    private func defaultTitle(for level: RiskLevel) -> String {
        switch level {
        case .low:       return "You're in good shape"
        case .medium:    return "Some concerns detected"
        case .high:      return "Medical attention advised"
        case .emergency: return "Seek emergency care immediately"
        }
    }

    private func defaultBody(for level: RiskLevel) -> String {
        switch level {
        case .low:       return "No major health concerns found. Stay hydrated and enjoy Bali!"
        case .medium:    return "Some risk factors were identified. Consult a doctor before traveling."
        case .high:      return "Significant health concerns detected. Please see a doctor as soon as possible."
        case .emergency: return "Emergency-level concerns detected. Seek immediate medical attention."
        }
    }

    // MARK: - Translation of dynamic assessment content (iOS 26+)

    @available(iOS 26.0, *)
    private func translateContent(from result: AssessmentResult) async {
        let deviceLang = Locale.current.language.languageCode?.identifier ?? "en"
        guard deviceLang != "id" else { return }

        let dict = TranslationDictionaryService.shared
        let candidates = [result.diagnosis, result.recommendation].filter { !$0.isEmpty }
        let toTranslate = candidates.filter { dict.lookup($0) == nil }
        guard !toTranslate.isEmpty else { return }

        let session = TranslationSession(
            installedSource: Locale.Language(identifier: "id"),
            target: Locale.current.language
        )
        if let responses = try? await session.translations(from: toTranslate.map {
            TranslationSession.Request(sourceText: $0, clientIdentifier: $0)
        }) {
            var batch: [String: String] = [:]
            for r in responses where !r.targetText.isEmpty {
                if let key = r.clientIdentifier { batch[key] = r.targetText }
            }
            await dict.storeBatch(batch)
        }
    }
}
