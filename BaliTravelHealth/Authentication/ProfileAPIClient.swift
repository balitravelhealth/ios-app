import Foundation

/// Syncs the local onboarding profile with the production traveler Gateway.
struct ProfileAPIClient: Sendable {
    static let shared = ProfileAPIClient()

    /// Sync onboarding payload. Travel dates remain local-only until the
    /// Gateway exposes a traveler trip endpoint.
    func upload(profile: UserProfile,
                travel _: TravelInfo?,
                sessionToken _: String) async throws {
        if AppFlags.useDummyData { return }

        let birthDate = SQLDateFormatter.string(from: profile.dateOfBirth)
        let emergencyContact = profile.emergencyContact?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let traveler = TravelerProfileRequest(
            namaLengkap: profile.name,
            tanggalLahir: birthDate,
            kontakDarurat: emergencyContact
        )
        let health = HealthProfileRequest(
            tanggalLahir: birthDate,
            jenisKelamin: profile.gender.jenisKelamin,
            tinggiCm: nil,
            beratKg: nil,
            golonganDarah: nil,
            riwayatAlergi: nil
        )

        try await upsert(path: "traveler-profile", payload: traveler)
        try await upsert(path: "health-profile", payload: health)
    }

    private func upsert<Payload: Encodable>(path: String, payload: Payload) async throws {
        var create = BaliAPI.authedRequest(path, method: "POST")
        create.httpBody = try BaliAPI.encoder.encode(payload)

        let (createData, createStatus) = try await BaliAPI.perform(create)
        if (200..<300).contains(createStatus) {
            return
        }
        if createStatus != 409 {
            throw BaliAPIError.from(data: createData, status: createStatus)
        }

        var update = BaliAPI.authedRequest(path, method: "PUT")
        update.httpBody = try BaliAPI.encoder.encode(payload)
        let (updateData, updateStatus) = try await BaliAPI.perform(update)
        guard (200..<300).contains(updateStatus) else {
            throw BaliAPIError.from(data: updateData, status: updateStatus)
        }
    }

    // MARK: - Fetch (resume after sign-in)

    struct FetchedProfile: Decodable, Sendable {
        let name: String
        let countryCode: String
        let dateOfBirth: String          // YYYY-MM-DD
        let gender: String
        let emergencyContact: String?
        let travel: FetchedTravel?

        struct FetchedTravel: Decodable, Sendable {
            let arrivalDate: String
            let departureDate: String
            let season: String?
        }
    }

    /// Pulls the user's saved profile from the server. Returns `nil` when
    /// the server has nothing on file (HTTP 204) — the iOS client should
    /// then route the user through onboarding.
    func fetch(sessionToken: String) async throws -> FetchedProfile? {
        if AppFlags.useDummyData { return nil }

        async let travelerResult = fetchTravelerProfile()
        async let healthResult = fetchHealthProfile()
        let (traveler, health) = try await (travelerResult, healthResult)

        guard let traveler else {
            return nil
        }
        guard let dateOfBirth = traveler.tanggalLahir, !dateOfBirth.isEmpty else {
            return nil
        }

        let gender = health?.jenisKelamin.gender.rawValue ?? Gender.male.rawValue
        return FetchedProfile(
            name: traveler.namaLengkap,
            countryCode: Locale.current.region?.identifier ?? "ID",
            dateOfBirth: dateOfBirth,
            gender: gender,
            emergencyContact: traveler.kontakDarurat,
            travel: nil
        )
    }

    private func fetchTravelerProfile() async throws -> TravelerProfile? {
        let req = BaliAPI.authedRequest("traveler-profile")
        let (data, status) = try await BaliAPI.perform(req)
        if status == 204 || status == 404 || data.isEmpty { return nil }
        guard (200..<300).contains(status) else {
            throw BaliAPIError.from(data: data, status: status)
        }
        return try BaliAPI.decode(TravelerProfile.self, from: data)
    }

    private func fetchHealthProfile() async throws -> HealthProfile? {
        let req = BaliAPI.authedRequest("health-profile")
        let (data, status) = try await BaliAPI.perform(req)
        if status == 204 || status == 404 || data.isEmpty { return nil }
        guard (200..<300).contains(status) else {
            throw BaliAPIError.from(data: data, status: status)
        }
        return try BaliAPI.decode(HealthProfile.self, from: data)
    }

}

private extension Gender {
    var jenisKelamin: JenisKelamin {
        switch self {
        case .male: return .lakiLaki
        case .female: return .perempuan
        }
    }
}

private extension Optional where Wrapped == JenisKelamin {
    var gender: Gender {
        switch self {
        case .some(.perempuan): return .female
        case .some(.lakiLaki), .none: return .male
        }
    }
}
