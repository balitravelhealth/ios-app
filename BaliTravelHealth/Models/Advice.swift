import Foundation

/// A single piece of personalised pre-travel advice.
/// Real content will arrive from a backend service or local rules engine later.
struct Advice: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let body: String
    let symbolName: String        // SF Symbol
    let severity: Severity

    enum Severity: String, Sendable {
        case info
        case warning
        case critical
    }

    init(id: UUID = UUID(),
         title: String,
         body: String,
         symbolName: String = "lightbulb.max",
         severity: Severity = .info) {
        self.id = id
        self.title = title
        self.body = body
        self.symbolName = symbolName
        self.severity = severity
    }
}
