import Foundation

enum AuthConfig {
    static let googleClientID = "779721266536-ean24hl5pgla3k3t98dodo66eacpl84r.apps.googleusercontent.com"

    static var googleRedirectScheme: String {
        let reversed = googleClientID
            .split(separator: ".")
            .reversed()
            .joined(separator: ".")
        return reversed
    }

    static var googleRedirectURI: String {
        "\(googleRedirectScheme):/oauthredirect"
    }

    static let sessionEndpoint = URL(string: "https://balihealth.me/internal/credentials.php")!
}
