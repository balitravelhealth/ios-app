import SwiftUI

struct HomeMenuItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let watermark: String
    let color: Color

    static let preTravel = HomeMenuItem(
        id: "preTravel",
        title: "Pre Travel",
        subtitle: "Prepare your health\nbefore traveling",
        symbol: "airplane.departure",
        watermark: "cross.case.fill",
        color: Color(red: 0.66, green: 0.86, blue: 0.85)   // mint
    )

    static let duringTravel = HomeMenuItem(
        id: "duringTravel",
        title: "During Travel",
        subtitle: "Track your health\nwhile traveling",
        symbol: "leaf.fill",
        watermark: "figure.walk",
        color: Color(red: 0.96, green: 0.86, blue: 0.42)   // warm yellow
    )

    static let postTravel = HomeMenuItem(
        id: "postTravel",
        title: "Post Travel",
        subtitle: "Health check-up\nafter traveling",
        symbol: "airplane.arrival",
        watermark: "heart.fill",
        color: Color(red: 0.55, green: 0.76, blue: 0.55)   // sage green
    )

    static let nursingCare = HomeMenuItem(
        id: "nursingCare",
        title: "Nursing Care",
        subtitle: "Get Nursing Care Service\nwhile traveling",
        symbol: "stethoscope",
        watermark: "stethoscope",
        color: Color(red: 0.82, green: 0.45, blue: 0.43)   // muted red
    )

    static let all: [HomeMenuItem] = [.preTravel, .duringTravel, .postTravel, .nursingCare]
}

struct HomeMenuCard: View {
    let item: HomeMenuItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // `Color.clear + aspectRatio` locks the cell to a square first,
            // then the overlay scales every element relative to that size.
            Color.clear
                .aspectRatio(1.0, contentMode: .fit)
                .overlay {
                    GeometryReader { geo in
                        let side = min(geo.size.width, geo.size.height)
                        let pad = side * 0.09

                        ZStack(alignment: .bottomTrailing) {
                            // Watermark — sized as a fraction of the card, never intrinsic
                            Image(systemName: item.watermark)
                                .resizable()
                                .scaledToFit()
                                .frame(width: side * 0.78, height: side * 0.78)
                                .foregroundStyle(.white.opacity(0.18))
                                .offset(x: side * 0.10, y: side * 0.10)

                            VStack(alignment: .leading, spacing: 0) {
                                Image(systemName: item.symbol)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: side * 0.18, height: side * 0.18)
                                    .foregroundStyle(.white)
                                    .padding(.bottom, side * 0.04)

                                Spacer(minLength: 0)

                                Text(item.title)
                                    .font(.system(size: side * 0.115, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)

                                Text(item.subtitle)
                                    .font(.system(size: side * 0.075, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.92))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.75)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(pad)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                }
                .background(item.color)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.title)
        .accessibilityHint(item.subtitle.replacingOccurrences(of: "\n", with: " "))
        .accessibilityAddTraits(.isButton)
    }
}
