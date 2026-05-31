import Network
import Foundation

/// Observable singleton that tracks real-time network connectivity.
/// Updated on the main actor whenever the underlying path changes.
@MainActor
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    /// `true` when the device has a usable network path (Wi-Fi, cellular, etc.)
    private(set) var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "balihealth.network.monitor", qos: .utility)

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isConnected = connected
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit {
        monitor.cancel()
    }
}
