import Foundation

/// Single source of truth for feature flags.
///
/// **Set `useDummyData = false` once your backend is wired up.**
/// While true:
///   - Sign in with Apple/Google bypasses OAuth & the server, creating a local
///     test user immediately.
///   - Profile, nurse list, and appointment endpoints return canned data and
///     persist to UserDefaults instead of hitting the network.
///   - The login screen shows an extra "Continue as Test User" button.
enum AppFlags {
    /// Default ON so the app is fully usable on-device with no backend.
    static let useDummyData: Bool = false
}
