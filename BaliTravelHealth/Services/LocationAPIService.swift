import Foundation

struct LocationAPIService: Sendable {
    static let shared = LocationAPIService()

    private static let baliCenter = (lat: -8.6705, lng: 115.2126)

    /// Classifies a coordinate as urban / rural / remote.
    func classifyLocation(lat: Double, lng: Double) async throws -> LocationClassification {
        let req = BaliAPI.request("location/classify", queryItems: [
            URLQueryItem(name: "lat", value: "\(lat)"),
            URLQueryItem(name: "lng", value: "\(lng)")
        ])
        return try await BaliAPI.perform(req, as: LocationClassification.self)
    }

    /// Returns health facilities within radius_km of the given coordinate.
    func fetchNearbyFacilities(lat: Double,
                                lng: Double,
                                radiusKm: Double = 20,
                                limit: Int = 10) async throws -> [NearbyHealthFacility] {
        let req = BaliAPI.request("facilities/nearby", queryItems: [
            URLQueryItem(name: "lat", value: "\(lat)"),
            URLQueryItem(name: "lng", value: "\(lng)"),
            URLQueryItem(name: "radius_km", value: "\(radiusKm)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ])
        return try await BaliAPI.performArray(req, of: NearbyHealthFacility.self)
    }

    /// Fetches a broad Bali-wide snapshot for offline access. The gateway
    /// exposes facilities through the nearby endpoint, so we query from central
    /// Bali with a wide radius and cache the database-backed response locally.
    func fetchFacilitiesForOfflineCache() async throws -> [NearbyHealthFacility] {
        try await fetchNearbyFacilities(
            lat: Self.baliCenter.lat,
            lng: Self.baliCenter.lng,
            radiusKm: 200,
            limit: 500
        )
    }
}
