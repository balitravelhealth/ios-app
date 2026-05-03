import Foundation
import CoreLocation

/// Async wrapper around `CLLocationManager` for one-shot location lookups.
///
/// Requires `NSLocationWhenInUseUsageDescription` in the Info.plist.
@MainActor
final class LocationFetcher: NSObject {

    enum LocationError: LocalizedError {
        case denied
        case unavailable

        var errorDescription: String? {
            switch self {
            case .denied: return "Location access is off. Turn it on in Settings to use your current address."
            case .unavailable: return "We couldn't get your location. Try entering your address manually."
            }
        }
    }

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authContinuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentLocation() async throws -> CLLocation {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            await waitForAuthorization()
        case .denied, .restricted:
            throw LocationError.denied
        default: break
        }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            break
        default:
            throw LocationError.denied
        }

        return try await withCheckedThrowingContinuation { cont in
            self.locationContinuation = cont
            manager.requestLocation()
        }
    }

    private func waitForAuthorization() async {
        await withCheckedContinuation { cont in
            self.authContinuation = cont
        }
    }
}

extension LocationFetcher: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last, let cont = locationContinuation else { return }
            locationContinuation = nil
            cont.resume(returning: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        Task { @MainActor in
            guard let cont = locationContinuation else { return }
            locationContinuation = nil
            cont.resume(throwing: LocationError.unavailable)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if let cont = authContinuation {
                authContinuation = nil
                cont.resume()
            }
        }
    }
}
