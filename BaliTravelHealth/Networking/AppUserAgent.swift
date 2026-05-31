import Foundation

/// Unique User-Agent header attached to every request that hits our backend.
/// The server rejects any request whose `User-Agent` doesn't start with the
/// `appKey` token, which keeps casual scrapers and curl probes out of the API.
///
/// **This is filtering, not security.** Anyone can sniff the value and replay
/// it. Continue to require the bearer session token on every protected route.
enum AppUserAgent {

    /// Shared secret prefix — any string the public can't easily guess.
    /// Change here, change in the server's allowlist.
    static let appKey: String = "BTH-IOS-7c3e9f"

    /// Header value sent on every backend request. Format:
    /// `BTH-IOS-7c3e9f BaliTravelHealth/1.0.0 (iOS 26.2; iPhone16,2)`
    static let value: String = {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = info?["CFBundleVersion"] as? String ?? "1"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        return "\(appKey) BaliTravelHealth/\(version) (\(build); \(osVersion); \(machine))"
    }()
}

extension URLRequest {
    /// Stamp the `User-Agent` header so our backend recognises the request.
    /// Call on every `URLRequest` that targets a Bali Travel Health endpoint.
    mutating func applyAppUserAgent() {
        setValue(AppUserAgent.value, forHTTPHeaderField: "User-Agent")
    }
}
