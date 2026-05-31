import Foundation

/// File-based JSON cache stored in Application Support.
/// All I/O is performed on a dedicated background actor so it never blocks the main thread.
actor LocalDataCache {
    static let shared = LocalDataCache()

    // MARK: - Keys

    enum Key: String {
        case emergencySteps       = "emergency_steps.json"
        case emergencyFlows       = "emergency_flows.json"
        case symptomsPreTravel    = "symptoms_pre_travel.json"
        case symptomsPostTravel   = "symptoms_post_travel.json"
        case nurses               = "nurses.json"
        case healthFacilities     = "health_facilities.json"

        /// Per-flow detail cache — one file per flow ID.
        static func flowDetail(_ id: Int) -> String { "flow_detail_\(id).json" }
    }

    // MARK: - First-fetch flag (UserDefaults, main-thread-safe)

    nonisolated var firstFetchComplete: Bool {
        get { UserDefaults.standard.bool(forKey: "balihealth.cache.firstFetchComplete") }
    }

    nonisolated func markFirstFetchComplete() {
        UserDefaults.standard.set(true, forKey: "balihealth.cache.firstFetchComplete")
    }

    nonisolated func resetFirstFetch() {
        UserDefaults.standard.removeObject(forKey: "balihealth.cache.firstFetchComplete")
    }

    // MARK: - Generic read / write

    func save<T: Encodable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: url(forKey: key), options: .atomic)
    }

    func load<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T? {
        let file = url(forKey: key)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let data = try Data(contentsOf: file)
        return try JSONDecoder().decode(type, from: data)
    }

    func exists(forKey key: String) -> Bool {
        FileManager.default.fileExists(atPath: url(forKey: key).path)
    }

    func clearAll() throws {
        let dir = cacheDirectory
        let files = try FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        )
        for file in files where file.pathExtension == "json" {
            try FileManager.default.removeItem(at: file)
        }
        resetFirstFetch()
    }

    // MARK: - Typed convenience helpers

    func saveSteps(_ steps: [EmergencyGuideStep]) throws {
        try save(steps, forKey: Key.emergencySteps.rawValue)
    }

    func loadSteps() throws -> [EmergencyGuideStep]? {
        try load([EmergencyGuideStep].self, forKey: Key.emergencySteps.rawValue)
    }

    func saveFlows(_ flows: [EmergencyGuideFlowSummary]) throws {
        try save(flows, forKey: Key.emergencyFlows.rawValue)
    }

    func loadFlows() throws -> [EmergencyGuideFlowSummary]? {
        try load([EmergencyGuideFlowSummary].self, forKey: Key.emergencyFlows.rawValue)
    }

    func saveFlowDetail(_ detail: EmergencyGuideFlowDetail) throws {
        try save(detail, forKey: Key.flowDetail(detail.id))
    }

    func loadFlowDetail(id: Int) throws -> EmergencyGuideFlowDetail? {
        try load(EmergencyGuideFlowDetail.self, forKey: Key.flowDetail(id))
    }

    func saveSymptoms(_ symptoms: [Symptom], for kategori: AssessmentKategori) throws {
        let key = kategori == .preTravel
            ? Key.symptomsPreTravel.rawValue
            : Key.symptomsPostTravel.rawValue
        try save(symptoms, forKey: key)
    }

    func loadSymptoms(for kategori: AssessmentKategori) throws -> [Symptom]? {
        let key = kategori == .preTravel
            ? Key.symptomsPreTravel.rawValue
            : Key.symptomsPostTravel.rawValue
        return try load([Symptom].self, forKey: key)
    }

    func saveNurses(_ nurses: [Nurse]) throws {
        try save(nurses, forKey: Key.nurses.rawValue)
    }

    func loadNurses() throws -> [Nurse]? {
        try load([Nurse].self, forKey: Key.nurses.rawValue)
    }

    func saveHealthFacilities(_ facilities: [NearbyHealthFacility]) throws {
        try save(facilities, forKey: Key.healthFacilities.rawValue)
    }

    func loadHealthFacilities() throws -> [NearbyHealthFacility]? {
        try load([NearbyHealthFacility].self, forKey: Key.healthFacilities.rawValue)
    }

    // MARK: - Translation dictionary  (Indonesian → target language)

    /// Key includes the target language so English, French, etc. get separate files.
    private func translationKey(targetLang: String) -> String {
        "translation_cache_id_to_\(targetLang).json"
    }

    func saveTranslations(_ dict: [String: String], targetLang: String) throws {
        try save(dict, forKey: translationKey(targetLang: targetLang))
    }

    func loadTranslations(targetLang: String) throws -> [String: String]? {
        try load([String: String].self, forKey: translationKey(targetLang: targetLang))
    }

    // MARK: - File URL helpers

    private var cacheDirectory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = base.appendingPathComponent("BaliHealthCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func url(forKey key: String) -> URL {
        cacheDirectory.appendingPathComponent(key)
    }
}
