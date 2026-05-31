import Foundation
import CoreLocation

@MainActor
@Observable
final class HealthFacilityStore {
    static let shared = HealthFacilityStore()

    private(set) var facilities: [NearbyHealthFacility] = []
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var userLocation: CLLocation?

    private var locationFetcher = LocationFetcher()
    private let cache = LocalDataCache.shared
    private let network = NetworkMonitor.shared

    private static let baliCenter = CLLocation(latitude: -8.6705, longitude: 115.2126)

    func refresh() async {
        if facilities.isEmpty {
            await loadCachedFacilities()
        }

        isLoading = true
        defer { isLoading = false }
        lastError = nil

        guard network.isConnected else {
            if facilities.isEmpty {
                lastError = "Facilities are unavailable offline until the first sync completes."
            }
            return
        }

        let location = await resolveLocation()
        userLocation = location

        do {
            let fresh = try await LocationAPIService.shared.fetchNearbyFacilities(
                lat: location.coordinate.latitude,
                lng: location.coordinate.longitude,
                radiusKm: 25,
                limit: 30
            )
            let cachedFacilities = try? await cache.loadHealthFacilities()
            facilities = merge(primary: fresh, fallback: cachedFacilities ?? [])
            if cachedFacilities?.isEmpty ?? true {
                try? await cache.saveHealthFacilities(fresh)
            }
        } catch {
            await loadCachedFacilities()
            if facilities.isEmpty {
                lastError = error.localizedDescription
            }
        }
    }

    func setFacilities(_ list: [NearbyHealthFacility]) {
        facilities = list
    }

    func loadCachedFacilities() async {
        if let cached = try? await cache.loadHealthFacilities(), !cached.isEmpty {
            facilities = cached
        }
    }

    func distanceString(for facility: NearbyHealthFacility) -> String {
        if let km = facility.jarakKm {
            return km < 1 ? String(format: "%.0f m", km * 1000) : String(format: "%.1f km", km)
        }
        guard let loc = userLocation else { return "" }
        let facilityLoc = CLLocation(latitude: facility.lat, longitude: facility.lng)
        let km = facilityLoc.distance(from: loc) / 1000
        return km < 1 ? String(format: "%.0f m", km * 1000) : String(format: "%.1f km", km)
    }

    private func resolveLocation() async -> CLLocation {
        do {
            return try await locationFetcher.currentLocation()
        } catch {
            return Self.baliCenter
        }
    }

    private func merge(
        primary: [NearbyHealthFacility],
        fallback: [NearbyHealthFacility]
    ) -> [NearbyHealthFacility] {
        var seen = Set<Int>()
        var merged: [NearbyHealthFacility] = []

        for facility in primary + fallback where !seen.contains(facility.id) {
            seen.insert(facility.id)
            merged.append(facility)
        }

        return merged
    }
}
