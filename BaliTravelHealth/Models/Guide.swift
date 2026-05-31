import Foundation

/// One emergency-guide topic.
///
/// Replace `Guide.placeholders` with the real catalog (or pull from a backend
/// / SwiftData later). Each guide can also expose an `imageName` matching an
/// asset in the catalog for the row thumbnail; `body` will hold the full
/// content once you add the detail screen.
struct Guide: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let summary: String
    let symbolName: String        // SF Symbol fallback for the thumbnail
    let imageName: String?        // optional asset name for a real thumbnail

    /// Placeholder catalog — swap for real content later.
    static let placeholders: [Guide] = [
        Guide(id: "cpr",
              title: "CPR Basics",
              summary: "How to perform chest compressions and rescue breaths.",
              symbolName: "heart.fill",
              imageName: nil),
        Guide(id: "choking",
              title: "Choking Relief",
              summary: "Steps for the abdominal thrust (Heimlich manoeuvre).",
              symbolName: "wind",
              imageName: nil),
        Guide(id: "burns",
              title: "Treating Burns",
              summary: "First aid for minor and severe burns.",
              symbolName: "flame.fill",
              imageName: nil),
        Guide(id: "bleeding",
              title: "Bleeding Control",
              summary: "How to stop heavy bleeding and dress a wound.",
              symbolName: "bandage.fill",
              imageName: nil),
        Guide(id: "heat",
              title: "Heat Stroke",
              summary: "Recognise the signs and cool a casualty quickly.",
              symbolName: "sun.max.fill",
              imageName: nil),
        Guide(id: "snake",
              title: "Snake & Insect Bites",
              summary: "What to do if bitten or stung in Bali.",
              symbolName: "ant.fill",
              imageName: nil),
        Guide(id: "drowning",
              title: "Drowning Response",
              summary: "Rescue, recovery position, and aftercare.",
              symbolName: "drop.fill",
              imageName: nil),
        Guide(id: "fracture",
              title: "Fractures & Sprains",
              summary: "Splinting and immobilising a limb safely.",
              symbolName: "figure.fall",
              imageName: nil)
    ]
}
