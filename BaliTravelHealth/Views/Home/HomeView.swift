import SwiftUI

struct HomeView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(\.verticalSizeClass) private var vSizeClass
    @State private var selection: HomeMenuItem?
    @State private var scrollOffset: CGFloat = 0   // >0 when content scrolled up, <0 on rubber-band pull-down

    private var displayName: String {
        let name = profileStore.profile?.name.trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty ? "Traveler" : name
    }

    private var firstName: String {
        displayName.split(separator: " ").first.map(String.init) ?? displayName
    }

    private var arrivalCountdown: ArrivalCountdown {
        ArrivalCountdown(arrival: profileStore.travelInfo?.arrivalDate)
    }

    var body: some View {
        GeometryReader { proxy in
            let heroHeight = heroHeight(for: proxy.size)

            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        cardGrid
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                            .padding(.bottom, 8)

                        // Tab bar breathing room (Liquid Glass dock + safe area)
                        Color.clear.frame(height: 96)
                    } header: {
                        hero(height: heroHeight, totalWidth: proxy.size.width)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemBackground))
            .ignoresSafeArea(edges: .top)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top
            } action: { _, newValue in
                scrollOffset = newValue
            }
            .refreshable {
                await profileStore.refresh()
            }
            .navigationDestination(item: $selection) { item in
                switch item.id {
                case HomeMenuItem.preTravel.id:
                    PreTravelView()
                case HomeMenuItem.duringTravel.id:
                    DuringTravelView()
                case HomeMenuItem.postTravel.id:
                    PostTravelView()
                case HomeMenuItem.nursingCare.id:
                    NursingCareView()
                default:
                    HomeMenuPlaceholder(item: item)
                }
            }
        }
    }

    // MARK: - Adaptive sizing

    private func heroHeight(for size: CGSize) -> CGFloat {
        if vSizeClass == .compact {                // landscape phones
            return max(200, size.height * 0.85)
        }
        // ~42% of screen height, clamped so SE doesn't get crushed and Pro Max doesn't bloat
        return min(max(size.height * 0.42, 280), 440)
    }

    // MARK: - Hero (sticky + parallax + blur)

    private func hero(height: CGFloat, totalWidth: CGFloat) -> some View {
        // Normalised scroll progress: 0 at top, 1 once cards have scrolled up by `height * 0.6`.
        let scrollProgress = max(0, min(1, scrollOffset / (height * 0.6)))
        // Pull-down stretch: positive only when user pulls past the top (rubber band).
        let stretch = max(0, -scrollOffset)
        // Parallax: image translates upward at 40% the rate of card scroll, so it appears to recede.
        let parallax = max(0, scrollOffset) * 0.4

        return ZStack(alignment: .topLeading) {
            // Background image — gets parallax + stretch + blur
            heroImage
                .frame(width: totalWidth, height: height + stretch)
                .scaleEffect(1 + (stretch / 600), anchor: .top)
                .offset(y: -parallax)
                .blur(radius: 22 * scrollProgress)
                .frame(width: totalWidth, height: height, alignment: .top)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [.black.opacity(0.55), .black.opacity(0.10), .black.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    // Liquid Glass-style frosting that fades in as we scroll
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(scrollProgress * 0.85)
                )

            // Foreground text — stays sharp; subtle parallax in the opposite direction so it feels layered
            VStack(alignment: .leading, spacing: 0) {
                welcomeRow
                    .padding(.horizontal, 20)
                    .padding(.top, 60)

                Spacer(minLength: 16)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Keep Healthy\nWhile in Bali")
                        .font(.system(size: dynamicTitleSize(height: height), weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)

                    countdownBadge
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
            }
            .frame(width: totalWidth, height: height, alignment: .topLeading)
            .opacity(Double(1 - scrollProgress * 0.85))
            .offset(y: -parallax * 0.25)   // text moves slightly slower than the image — depth cue
        }
        .frame(width: totalWidth, height: height)
        .background(Color(.systemBackground))   // prevents see-through while pinned
        .clipped()
        .animation(.easeOut(duration: 0.12), value: scrollProgress)
    }

    private func dynamicTitleSize(height: CGFloat) -> CGFloat {
        switch height {
        case ..<260: return 24
        case ..<340: return 28
        default:     return 34
        }
    }

    @ViewBuilder
    private var heroImage: some View {
        if UIImage(named: "NusaPenidaHeader") != nil {
            Image("NusaPenidaHeader")
                .resizable()
                .scaledToFill()
        } else if UIImage(named: "BaliHeader") != nil {
            Image("BaliHeader")
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.50, blue: 0.65),
                         Color(red: 0.03, green: 0.27, blue: 0.43)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var welcomeRow: some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 0) {
                Text("Welcome back,")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                Text(firstName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Welcome back, \(displayName)")
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 44, height: 44)
            Image(systemName: "person.fill")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Color(red: 0.62, green: 0.55, blue: 0.86))
        }
    }

    private var countdownBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: arrivalCountdown.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(.white.opacity(0.18)))

            Text(arrivalCountdown.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 2x2 grid

    private var cardGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(HomeMenuItem.all) { item in
                HomeMenuCard(item: item) {
                    selection = item
                }
            }
        }
    }
}

// MARK: - Countdown helper

struct ArrivalCountdown {
    let arrival: Date?

    var days: Int? {
        guard let arrival else { return nil }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.startOfDay(for: arrival)
        return cal.dateComponents([.day], from: start, to: end).day
    }

    var message: String {
        guard let days else {
            return "Add your travel dates to see your countdown"
        }
        switch days {
        case let d where d > 1:
            return "You're going to Bali in \(d) days"
        case 1:
            return "You're going to Bali tomorrow"
        case 0:
            return "You're arriving in Bali today"
        case -1:
            return "You arrived in Bali yesterday"
        default:
            return "Enjoy your stay in Bali"
        }
    }

    var symbol: String {
        guard let days else { return "calendar.badge.plus" }
        return days >= 0 ? "alarm" : "sun.max.fill"
    }
}

// MARK: - Placeholder destination

struct HomeMenuPlaceholder: View {
    let item: HomeMenuItem
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: item.symbol)
                .font(.system(size: 56))
                .foregroundStyle(item.color)
            Text(item.title)
                .font(.title.weight(.bold))
            Text("Coming soon")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environment(ProfileStore())
    }
}
