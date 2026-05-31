import Foundation
import Translation

/// Drives the app-startup sequence:
///
/// - **First install** (or after cache clear): connect → fetch all public data → save to cache → ready.
/// - **Returning user, online**: re-fetch in background while showing the splash briefly.
/// - **Returning user, offline + cached**: load from cache instantly, mark features that
///   need live data as unavailable.
/// - **Returning user, offline, no cache**: open app with all network features unavailable.
@MainActor
@Observable
final class AppLaunchCoordinator {
    static let shared = AppLaunchCoordinator()

    enum State {
        /// Initial value before `performLaunch()` is called.
        case idle
        /// Fetching and caching data — the splash screen is shown.
        case fetching
        /// Data is ready (from network or cache). Normal app flow.
        case ready
        /// Device is offline *and* no cache exists yet. All data-dependent features unavailable.
        case offlineNoCache
    }

    private(set) var state: State = .idle
    /// Human-readable status shown under the splash spinner.
    private(set) var statusMessage: String = ""

    private let cache = LocalDataCache.shared
    private let network = NetworkMonitor.shared

    // MARK: - Entry point

    /// Call once when the app becomes active after the user has authenticated.
    func performLaunch() async {
        guard state == .idle else { return }
        state = .fetching

        // Always warm the translation dictionary from disk first — it's a fast
        // file read and ensures TranslatingText can show cached English instantly.
        await TranslationDictionaryService.shared.load()

        if network.isConnected {
            await fetchAndCache()
            state = .ready
        } else if cache.firstFetchComplete {
            // Warm start from cache — no spinner needed, just transition directly
            await loadFromCache()
            state = .ready
        } else {
            // First launch with no network and no cache
            state = .offlineNoCache
        }
    }

    // MARK: - Online path: fetch everything and persist

    private func fetchAndCache() async {
        statusMessage = NSLocalizedString("Updating guides…", comment: "Launch progress")

        async let steps    = fetchSteps()
        async let flows    = fetchFlows()
        async let sympPre  = fetchSymptoms(.preTravel)
        async let sympPost = fetchSymptoms(.postTravel)
        async let nurses   = fetchNurses()
        async let facilities = fetchFacilities()

        let (stepsResult, flowsResult, _, _, _, _) = await (steps, flows, sympPre, sympPost, nurses, facilities)

        // Pre-fetch every flow detail so it's available offline
        if case .success(let summaries) = flowsResult {
            await withTaskGroup(of: Void.self) { group in
                for summary in summaries {
                    group.addTask { await self.fetchAndCacheFlowDetail(id: summary.id) }
                }
            }
        }

        // Batch-translate all guide strings while splash is still showing (iOS 26+)
        if #available(iOS 26.0, *) {
            let stepsToTranslate: [EmergencyGuideStep]
            let flowsToTranslate: [EmergencyGuideFlowSummary]
            if case .success(let s) = stepsResult { stepsToTranslate = s } else { stepsToTranslate = [] }
            if case .success(let f) = flowsResult { flowsToTranslate = f } else { flowsToTranslate = [] }
            await translateGuideContent(steps: stepsToTranslate, flows: flowsToTranslate)
        }

        // Suppress unused-result warnings — errors are logged inside each helper
        _ = stepsResult

        cache.markFirstFetchComplete()
        statusMessage = ""
    }

    // MARK: - Batch translation (iOS 17.4+)

    @available(iOS 26.0, *)
    private func translateGuideContent(
        steps: [EmergencyGuideStep],
        flows: [EmergencyGuideFlowSummary]
    ) async {
        let deviceLang = Locale.current.language.languageCode?.identifier ?? "en"
        guard deviceLang != "id" else { return }  // Indonesian device — no translation needed

        // Collect every unique non-empty Indonesian string from guide content
        var strings: Set<String> = []

        for step in steps {
            if let judul = step.isiMedia?.judul, !judul.isEmpty { strings.insert(judul) }
            if let teks = step.isiMedia?.teks, !teks.isEmpty { strings.insert(teks) }
        }

        for flow in flows {
            if !flow.title.isEmpty { strings.insert(flow.title) }
            if let desc = flow.deskripsi, !desc.isEmpty { strings.insert(desc) }

            // Pull nodes from the detail files that were just pre-cached
            if let detail = try? await cache.loadFlowDetail(id: flow.id) {
                if !detail.title.isEmpty { strings.insert(detail.title) }
                if let desc = detail.deskripsi, !desc.isEmpty { strings.insert(desc) }
                for node in detail.nodes {
                    if !node.title.isEmpty { strings.insert(node.title) }
                    if !node.instruction.isEmpty { strings.insert(node.instruction) }
                    node.choices?.forEach { if !$0.label.isEmpty { strings.insert($0.label) } }
                }
            }
        }

        // Skip strings already in the dictionary
        let dictionary = TranslationDictionaryService.shared
        let toTranslate = strings.filter { dictionary.lookup($0) == nil }
        guard !toTranslate.isEmpty else { return }

        statusMessage = NSLocalizedString("Translating content…", comment: "Launch progress")

        let sourceLang = Locale.Language(identifier: "id")
        let targetLang = Locale.current.language
        let session = TranslationSession(installedSource: sourceLang, target: targetLang)

        do {
            let requests = toTranslate.map {
                TranslationSession.Request(sourceText: $0, clientIdentifier: $0)
            }
            let responses = try await session.translations(from: requests)
            var batch: [String: String] = [:]
            for response in responses {
                if let key = response.clientIdentifier, !response.targetText.isEmpty {
                    batch[key] = response.targetText
                }
            }
            await dictionary.storeBatch(batch)
        } catch {
            // Translation models unavailable or language pair unsupported —
            // strings will fall back to displaying the original Indonesian text.
        }
    }

    @discardableResult
    private func fetchSteps() async -> Result<[EmergencyGuideStep], Error> {
        do {
            let req = BaliAPI.request("emergency-guides")
            let steps = try await BaliAPI.performArray(req, of: EmergencyGuideStep.self)
            try await cache.saveSteps(steps)
            await EmergencyGuideAPIService.shared.setSteps(steps)
            return .success(steps)
        } catch {
            // Fallback to whatever is already in the service (may be empty)
            return .failure(error)
        }
    }

    @discardableResult
    private func fetchFlows() async -> Result<[EmergencyGuideFlowSummary], Error> {
        do {
            let req = BaliAPI.request("emergency-guide-flows")
            let flows = try await BaliAPI.performArray(req, of: EmergencyGuideFlowSummary.self)
            try await cache.saveFlows(flows)
            await EmergencyGuideAPIService.shared.setFlows(flows)
            return .success(flows)
        } catch {
            return .failure(error)
        }
    }

    private func fetchAndCacheFlowDetail(id: Int) async {
        do {
            let req = BaliAPI.request("emergency-guide-flows/\(id)")
            let detail = try await BaliAPI.perform(req, as: EmergencyGuideFlowDetail.self)
            try await cache.saveFlowDetail(detail)
        } catch {
            // Non-fatal — detail will be fetched on-demand when user opens the flow
        }
    }

    @discardableResult
    private func fetchSymptoms(_ kategori: AssessmentKategori) async -> Result<[Symptom], Error> {
        do {
            let symptoms = try await AssessmentService.shared.fetchSymptoms(kategori: kategori)
            try await cache.saveSymptoms(symptoms, for: kategori)
            return .success(symptoms)
        } catch {
            return .failure(error)
        }
    }

    @discardableResult
    private func fetchNurses() async -> Result<[Nurse], Error> {
        do {
            statusMessage = NSLocalizedString("Loading nurses…", comment: "Launch progress")
            let req = BaliAPI.authedRequest("nurses")
            let apiNurses = try await BaliAPI.performArray(req, of: APINurse.self)
            let nurses = apiNurses.map { n in
                Nurse(
                    id: String(n.id),
                    name: n.namaLengkap,
                    experience: n.sertifikasi,
                    baseRate: 0,
                    currencyCode: "IDR",
                    avatarURL: nil,
                    bio: n.nomorLisensi.map { "License: \($0)" }
                )
            }
            try await cache.saveNurses(nurses)
            await NurseService.shared.setNurses(nurses)
            return .success(nurses)
        } catch {
            return .failure(error)
        }
    }

    @discardableResult
    private func fetchFacilities() async -> Result<[NearbyHealthFacility], Error> {
        do {
            statusMessage = NSLocalizedString("Loading health facilities…", comment: "Launch progress")
            let facilities = try await LocationAPIService.shared.fetchFacilitiesForOfflineCache()
            try await cache.saveHealthFacilities(facilities)
            HealthFacilityStore.shared.setFacilities(facilities)
            return .success(facilities)
        } catch {
            return .failure(error)
        }
    }

    // Private mirror of NurseService.APINurse (avoids exposing it)
    private struct APINurse: Decodable {
        let id: Int
        let namaLengkap: String
        let nomorLisensi: String?
        let sertifikasi: String
    }

    // MARK: - Offline path: warm from cache

    private func loadFromCache() async {
        // Translation dictionary is already loaded in performLaunch() before this call
        if let steps = try? await cache.loadSteps() {
            await EmergencyGuideAPIService.shared.setSteps(steps)
        }
        if let flows = try? await cache.loadFlows() {
            await EmergencyGuideAPIService.shared.setFlows(flows)
        }
        if let nurses = try? await cache.loadNurses() {
            await NurseService.shared.setNurses(nurses)
        }
        if let facilities = try? await cache.loadHealthFacilities() {
            await HealthFacilityStore.shared.setFacilities(facilities)
        }
        // Symptoms are loaded on-demand by ExpertSymptomService
    }
}
