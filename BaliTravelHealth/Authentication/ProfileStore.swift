import Foundation

/// Persists the user's onboarding profile + travel info locally (UserDefaults)
/// and syncs to the server once both are entered.
@MainActor
@Observable
final class ProfileStore {
    private let defaults: UserDefaults
    private let profileKey       = "com.balitravelhealth.userProfile"
    private let travelKey        = "com.balitravelhealth.travelInfo"
    private let onboardingKey    = "com.balitravelhealth.onboardingComplete"
    private let hraKey           = "com.balitravelhealth.healthRiskAssessmentComplete"

    private(set) var profile: UserProfile?
    private(set) var travelInfo: TravelInfo?
    private(set) var didCompleteOnboarding: Bool
    private(set) var hasCompletedHealthRiskAssessment: Bool

    var isProfileComplete: Bool { profile != nil }
    var hasTravelInfo: Bool { travelInfo != nil }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.profile = Self.load(UserProfile.self, from: defaults, key: profileKey)
        self.travelInfo = Self.load(TravelInfo.self, from: defaults, key: travelKey)
        self.didCompleteOnboarding = defaults.bool(forKey: onboardingKey)
        self.hasCompletedHealthRiskAssessment = defaults.bool(forKey: hraKey)
    }

    /// Call this from the Health Risk Assessment screen once the user finishes
    /// it; the Profile screen's Health Pass card uses this flag to decide
    /// whether to render.
    func setHealthRiskAssessmentCompleted(_ completed: Bool) {
        hasCompletedHealthRiskAssessment = completed
        defaults.set(completed, forKey: hraKey)
    }

    // MARK: - Save

    func saveProfile(_ profile: UserProfile) {
        self.profile = profile
        persist(profile, key: profileKey)
    }

    func saveTravelInfo(_ info: TravelInfo) {
        self.travelInfo = info
        persist(info, key: travelKey)
    }

    /// Mark onboarding done. If `skippingTravel` is true, travel info is left nil.
    /// Always attempts a server sync (silently ignores network failures so the
    /// user is never blocked from entering the app).
    func completeOnboarding(skippingTravel: Bool) async {
        if skippingTravel {
            travelInfo = nil
            defaults.removeObject(forKey: travelKey)
        }
        didCompleteOnboarding = true
        defaults.set(true, forKey: onboardingKey)

        await syncToServer()
    }

    func clear() {
        profile = nil
        travelInfo = nil
        didCompleteOnboarding = false
        hasCompletedHealthRiskAssessment = false
        defaults.removeObject(forKey: profileKey)
        defaults.removeObject(forKey: travelKey)
        defaults.removeObject(forKey: onboardingKey)
        defaults.removeObject(forKey: hraKey)
    }

    // MARK: - Server sync

    /// Pull-to-refresh entry point. Re-uploads the local copy and gives the
    /// SwiftUI refresh indicator enough time to feel responsive.
    func refresh() async {
        async let sync: Void = syncToServer()
        async let pause: Void = pauseForFeedback()
        _ = await (sync, pause)
    }

    private func pauseForFeedback() async {
        try? await Task.sleep(nanoseconds: 600_000_000)
    }

    func syncToServer() async {
        guard let profile,
              let token = KeychainManager.shared.get(.sessionToken) else { return }
        do {
            try await ProfileAPIClient.shared.upload(
                profile: profile,
                travel: travelInfo,
                sessionToken: token
            )
        } catch {
            // Silent failure — local copy is the source of truth; retry on next launch.
        }
    }

    /// Pull the saved profile + travel from the server and apply locally.
    /// Called from `AuthenticationManager` right after a successful sign-in
    /// so the user goes straight to Home if they already onboarded on a
    /// previous device or before signing out.
    ///
    /// Returns `true` if a profile was found server-side (and onboarding is
    /// now complete locally), `false` otherwise (user needs onboarding).
    @discardableResult
    func refreshFromServer() async -> Bool {
        guard let token = KeychainManager.shared.get(.sessionToken) else { return false }

        let fetched: ProfileAPIClient.FetchedProfile?
        do {
            fetched = try await ProfileAPIClient.shared.fetch(sessionToken: token)
        } catch {
            // Network or decode error — leave local state alone, treat as
            // "we don't know" rather than wiping anything.
            return didCompleteOnboarding
        }

        guard let fetched else {
            // Server confirms there's no profile yet → onboarding is required.
            return false
        }

        let dobFormatter = DateFormatter()
        dobFormatter.dateFormat = "yyyy-MM-dd"
        dobFormatter.timeZone   = TimeZone(secondsFromGMT: 0)
        guard let dob = dobFormatter.date(from: fetched.dateOfBirth),
              let gender = Gender(rawValue: fetched.gender) else {
            return false
        }

        let profile = UserProfile(
            name: fetched.name,
            countryCode: fetched.countryCode,
            dateOfBirth: dob,
            gender: gender
        )
        saveProfile(profile)

        if let travel = fetched.travel,
           let arrival   = dobFormatter.date(from: travel.arrivalDate),
           let departure = dobFormatter.date(from: travel.departureDate) {
            saveTravelInfo(TravelInfo(arrivalDate: arrival, departureDate: departure))
        } else {
            travelInfo = nil
            defaults.removeObject(forKey: travelKey)
        }

        didCompleteOnboarding = true
        defaults.set(true, forKey: onboardingKey)
        return true
    }

    // MARK: - Private

    private func persist<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
